#!/usr/bin/env bash
set -euo pipefail

mkdir -p app/src/main/java/com/example/sunalarm

cat > app/src/main/java/com/example/sunalarm/SunView.java <<'EOF'
package com.example.sunalarm;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.util.AttributeSet;
import android.view.View;

import java.util.Random;

public class SunView extends View {

    private float progress = 0f;
    private boolean sunset = false;

    private final Paint glowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint corePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint starPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint farHillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint nearHillPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Path farHills;
    private Path nearHills;
    private float[] stars; // x, y, r, baseAlpha
    private int starCount;
    private int sceneW;
    private int sceneH;

    public SunView(Context context) { super(context); init(); }
    public SunView(Context context, AttributeSet attrs) { super(context, attrs); init(); }
    public SunView(Context context, AttributeSet attrs, int defStyleAttr) { super(context, attrs, defStyleAttr); init(); }

    private void init() {
        starPaint.setColor(0xFFFFFFFF);
        farHillPaint.setColor(0x4010233F);
        farHillPaint.setStyle(Paint.Style.FILL);
        nearHillPaint.setColor(0x990A1730);
        nearHillPaint.setStyle(Paint.Style.FILL);
    }

    public void setSunset(boolean sunset) { this.sunset = sunset; invalidate(); }

    public void setProgress(float progress) {
        this.progress = Math.max(0f, Math.min(1f, progress));
        invalidate();
    }

    private void ensureScene(int w, int h) {
        if (w == sceneW && h == sceneH && farHills != null) return;
        sceneW = w;
        sceneH = h;

        Random rnd = new Random(20260728L);

        farHills = buildHills(w, h, h * 0.80f, h * 0.07f, 7, rnd);
        nearHills = buildHills(w, h, h * 0.90f, h * 0.11f, 5, rnd);

        starCount = 70;
        stars = new float[starCount * 4];
        Random srnd = new Random(7L);
        for (int i = 0; i < starCount; i++) {
            stars[i * 4] = srnd.nextFloat() * w;
            stars[i * 4 + 1] = srnd.nextFloat() * h * 0.70f;
            stars[i * 4 + 2] = 0.6f + srnd.nextFloat() * 1.6f;
            stars[i * 4 + 3] = 0.4f + srnd.nextFloat() * 0.6f;
        }
    }

    private Path buildHills(int w, int h, float baseY, float amp, int peaks, Random rnd) {
        Path p = new Path();
        p.moveTo(0f, h);
        p.lineTo(0f, baseY);
        int steps = peaks * 2;
        for (int i = 1; i <= steps; i++) {
            float x = w * (i / (float) steps);
            float y = baseY - (i % 2 == 1 ? amp * (0.5f + rnd.nextFloat() * 0.5f) : amp * 0.15f * rnd.nextFloat());
            p.lineTo(x, y);
        }
        p.lineTo(w, baseY);
        p.lineTo(w, h);
        p.close();
        return p;
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        int w = getWidth();
        int h = getHeight();
        if (w == 0 || h == 0) return;
        ensureScene(w, h);

        // Ночной фактор: на восходе ночь уходит (1->0), на закате приходит (0->1).
        float night = sunset ? progress : (1f - progress);

        // 1) Звёзды (дальний план).
        if (night > 0.02f) {
            for (int i = 0; i < starCount; i++) {
                int a = (int) (stars[i * 4 + 3] * night * 255f);
                if (a < 3) continue;
                starPaint.setAlpha(a);
                canvas.drawCircle(stars[i * 4], stars[i * 4 + 1], stars[i * 4 + 2], starPaint);
            }
            starPaint.setAlpha(255);
        }

        // 2) Солнце с сиянием.
        float horizonY = h * 0.80f;
        float t = sunset ? (1f - progress) : progress;
        float startY = h * 1.08f;
        float endY = h * 0.20f;
        float sunY = startY + (endY - startY) * t;
        float sunX = w / 2f;

        float radius = Math.min(w, h) * 0.16f;     // было 0.09 — солнце крупнее
        float glowRadius = radius * 3.6f;

        float denom = horizonY - endY;
        float warmth = 1f - Math.max(0f, Math.min(1f, (horizonY - sunY) / denom));
        int coreColor = lerpColor(0xFFFFF3C4, 0xFFFFB74D, warmth);
        int glowColor = lerpColor(0x66FFD54F, 0x8CFF7043, warmth);

        glowPaint.setShader(new RadialGradient(sunX, sunY, glowRadius,
                new int[]{glowColor, withAlpha(glowColor, 0.3f), 0x00000000},
                new float[]{0f, 0.45f, 1f}, Shader.TileMode.CLAMP));
        canvas.drawCircle(sunX, sunY, glowRadius, glowPaint);

        corePaint.setColor(coreColor);
        canvas.drawCircle(sunX, sunY, radius, corePaint);

        // 3) Холмы (передний план — солнце прячется за ними у горизонта).
        canvas.drawPath(farHills, farHillPaint);
        canvas.drawPath(nearHills, nearHillPaint);
    }

    private static int lerpColor(int c1, int c2, float f) {
        return Color.argb(
                (int) (Color.alpha(c1) + (Color.alpha(c2) - Color.alpha(c1)) * f),
                (int) (Color.red(c1) + (Color.red(c2) - Color.red(c1)) * f),
                (int) (Color.green(c1) + (Color.green(c2) - Color.green(c1)) * f),
                (int) (Color.blue(c1) + (Color.blue(c2) - Color.blue(c1)) * f));
    }

    private static int withAlpha(int color, float scale) {
        return Color.argb((int) (Color.alpha(color) * scale),
                Color.red(color), Color.green(color), Color.blue(color));
    }
}
EOF

echo "gen5: OK"
