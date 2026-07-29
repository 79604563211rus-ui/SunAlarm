#!/usr/bin/env bash
set -euo pipefail
mkdir -p app/src/main/java/com/example/sunalarm

cat > app/src/main/java/com/example/sunalarm/SunView.java <<'EOF'
package com.example.sunalarm;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.Shader;
import android.os.SystemClock;
import android.util.AttributeSet;
import android.view.View;

import java.util.ArrayList;
import java.util.Random;

/** Анимированная сцена: солнце/луна по траекториям, звёзды, падающие звёзды, 4 темы. */
public class SunView extends View {

    private float progress = 0f;
    private boolean sunset = false;
    private int theme = SunTheme.HILLS;
    private boolean animated = true;

    private final Paint glow = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint core = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint star = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint far = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint near = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint moon = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint moonGlow = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint crater = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint shoot = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint water = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint glint = new Paint(Paint.ANTI_ALIAS_FLAG);

    private Path farPath, nearPath;
    private float[] stars;     // x, y, r, baseAlpha, phase
    private int starCount;
    private float[] spikes;    // x, w, h (торосы для ICE)
    private int spikeCount;
    private int sceneW, sceneH, sceneType = -1, sceneTheme = -1;

    private final ArrayList<Shoot> shoots = new ArrayList<>();
    private long nextShootMs;
    private long startMs;
    private ValueAnimator tick;
    private final Random rnd = new Random(20260728L);

    private static final class Shoot {
        float x0, y0, vx, vy; long born, life;
        Shoot(float x0,float y0,float vx,float vy,long born,long life){
            this.x0=x0;this.y0=y0;this.vx=vx;this.vy=vy;this.born=born;this.life=life;
        }
    }

    public SunView(Context c){super(c);init();}
    public SunView(Context c,AttributeSet a){super(c,a);init();}
    public SunView(Context c,AttributeSet a,int d){super(c,a,d);init();}

    private void init(){
        star.setColor(0xFFFFFFFF);
        far.setStyle(Paint.Style.FILL);
        near.setStyle(Paint.Style.FILL);
        water.setStyle(Paint.Style.FILL);
        crater.setColor(0x33A9B4C2);
        shoot.setColor(0xFFFFFFFF);
        shoot.setStrokeWidth(2f);
        shoot.setStrokeCap(Paint.Cap.ROUND);
    }

    public void setSunset(boolean s){ this.sunset=s; invalidate(); }
    public void setTheme(int t){ this.theme=t; sceneType=-1; invalidate(); }
    public void setProgress(float p){ this.progress=Math.max(0f,Math.min(1f,p)); invalidate(); }

    public void setAnimated(boolean a){
        this.animated=a;
        if (isAttachedToWindow()) { if (a) startTick(); else stopTick(); }
        invalidate();
    }

    @Override protected void onAttachedToWindow(){ super.onAttachedToWindow(); if (animated) startTick(); }
    @Override protected void onDetachedFromWindow(){ stopTick(); super.onDetachedFromWindow(); }

    private void startTick(){
        if (tick != null) return;
        startMs = SystemClock.uptimeMillis();
        nextShootMs = startMs + 4000;
        tick = ValueAnimator.ofFloat(0f, 1f);
        tick.setDuration(40);
        tick.setRepeatCount(ValueAnimator.INFINITE);
        tick.addUpdateListener(a -> invalidate());
        tick.start();
    }
    private void stopTick(){ if (tick != null){ tick.cancel(); tick=null; } }

    private void ensureScene(int w, int h){
        int st = SunTheme.scene(theme);
        if (w == sceneW && h == sceneH && st == sceneType && theme == sceneTheme && farPath != null) return;
        sceneW = w; sceneH = h; sceneType = st; sceneTheme = theme;

        Random r = new Random(101L + theme);
        if (st == SunTheme.SCENE_HILLS) {
            farPath  = hills(w, h, h*0.80f, h*0.07f, 7, r);
            nearPath = hills(w, h, h*0.90f, h*0.11f, 5, r);
        } else if (st == SunTheme.SCENE_DUNES) {
            farPath  = hills(w, h, h*0.72f, h*0.10f, 3, r);
            nearPath = hills(w, h, h*0.84f, h*0.13f, 2, r);
        } else {
            farPath = new Path(); nearPath = new Path();
        }

        if (st == SunTheme.SCENE_ICE) {
            spikeCount = 12;
            spikes = new float[spikeCount*3];
            Random ir = new Random(55L);
            for (int i=0;i<spikeCount;i++){
                spikes[i*3]   = ir.nextFloat()*w;
                spikes[i*3+1] = w*(0.03f+ir.nextFloat()*0.05f);
                spikes[i*3+2] = h*(0.02f+ir.nextFloat()*0.05f);
            }
        } else { spikeCount = 0; spikes = null; }

        starCount = 80;
        stars = new float[starCount*5];
        Random sr = new Random(7L);
        for (int i=0;i<starCount;i++){
            stars[i*5]   = sr.nextFloat()*w;
            stars[i*5+1] = sr.nextFloat()*h*0.62f;
            stars[i*5+2] = 0.6f+sr.nextFloat()*1.6f;
            stars[i*5+3] = 0.4f+sr.nextFloat()*0.6f;
            stars[i*5+4] = sr.nextFloat()*6.283f;
        }
    }

    private Path hills(int w, int h, float baseY, float amp, int peaks, Random r){
        Path p = new Path();
        p.moveTo(0f, h); p.lineTo(0f, baseY);
        int steps = peaks*2;
        for (int i=1;i<=steps;i++){
            float x = w*(i/(float)steps);
            float y = baseY - (i%2==1 ? amp*(0.5f+r.nextFloat()*0.5f) : amp*0.15f*r.nextFloat());
            p.lineTo(x, y);
        }
        p.lineTo(w, baseY); p.lineTo(w, h); p.close();
        return p;
    }

    @Override
    protected void onDraw(Canvas c){
        super.onDraw(c);
        int w = getWidth(), h = getHeight();
        if (w == 0 || h == 0) return;
        ensureScene(w, h);

        float daylight = sunset ? (1f - progress) : progress;
        float nightF = 1f - daylight;

        float horizonY = h * SunTheme.horizonFrac(theme);

        // --- Солнце: восход поднимается, закат опускается ---
        float tSun = sunset ? (1f - progress) : progress;
        float sunY = h*1.08f + (h*0.18f - h*1.08f) * tSun;
        float sunX = w/2f;
        float radius = Math.min(w, h) * 0.16f;
        float glowR = radius * 3.6f;
        float warmth = 1f - Math.max(0f, Math.min(1f, (horizonY - sunY)/(horizonY - h*0.18f)));
        int coreCol = SunTheme.lerpColor(0xFFFFF3C4, 0xFFFFB74D, warmth);
        int glowCol = SunTheme.lerpColor(0x66FFD54F, 0x8CFF7043, warmth);

        // --- Звёзды ---
        if (nightF > 0.02f){
            float now = animated ? (SystemClock.uptimeMillis() - startMs)/1000f : 0f;
            for (int i=0;i<starCount;i++){
                float base = stars[i*5+3];
                float tw = animated ? (0.55f + 0.45f*(float)Math.sin(now*2.0 + stars[i*5+4])) : 1f;
                int a = (int)(base * nightF * tw * 255f);
                if (a < 3) continue;
                star.setAlpha(a);
                c.drawCircle(stars[i*5], stars[i*5+1], stars[i*5+2], star);
            }
            star.setAlpha(255);
        }

        // --- Солнце (рисуем до переднего плана, чтобы пряталось за горизонт) ---
        glow.setShader(new RadialGradient(sunX, sunY, glowR,
                new int[]{glowCol, withAlpha(glowCol,0.3f), 0x00000000},
                new float[]{0f,0.45f,1f}, Shader.TileMode.CLAMP));
        c.drawCircle(sunX, sunY, glowR, glow);
        core.setColor(coreCol);
        c.drawCircle(sunX, sunY, radius, core);

        // --- Луна: траектория ПРОТИВОФАЗНА солнцу, по центру, зенит в середине экрана ---
        // nightF=1 (ночь) -> луна высоко; nightF=0 (день) -> луна за горизонтом.
        // Утром (восход) nightF падает => луна опускается = садится.
        // Вечером (закат) nightF растёт => луна поднимается = встаёт.
        float moonT = nightF;
        float mx = w / 2f;                       // центр по горизонтали (под часами)
        float mr = Math.min(w, h) * 0.085f;
        float myTop = h * 0.46f;                 // зенит = середина экрана, ниже часов
        float my = h * 1.08f + (myTop - h * 1.08f) * moonT;
        float moonA = Math.max(0f, Math.min(1f, (nightF - 0.15f) / 0.35f));

        if (moonA > 0.01f && my < h + mr){
            moon.setAlpha((int)(moonA * 255f));
            moon.setColor(0xFFE8EEF5);
            moonGlow.setShader(new RadialGradient(mx, my, mr*1.8f,
                    new int[]{withAlpha(0xFFE8EEF5, moonA*0.25f), 0x00000000},
                    new float[]{0f, 1f}, Shader.TileMode.CLAMP));
            c.drawCircle(mx, my, mr*1.8f, moonGlow);
            c.drawCircle(mx, my, mr, moon);
            crater.setAlpha((int)(moonA * 0x55));
            c.drawCircle(mx - mr*0.30f, my - mr*0.20f, mr*0.22f, crater);
            c.drawCircle(mx + mr*0.25f, my + mr*0.25f, mr*0.16f, crater);
            c.drawCircle(mx + mr*0.10f, my - mr*0.35f, mr*0.12f, crater);
            moon.setAlpha(255); crater.setAlpha(0x33A9B4C2);
        }

        // --- Передний план ПОСЛЕ солнца и луны => они заходят за горизонт ---
        drawForeground(c, w, h, daylight, sunX, horizonY, coreCol);

        // --- Падающие звёзды ---
        if (animated && nightF > 0.5f){
            long nowMs = SystemClock.uptimeMillis();
            if (nowMs > nextShootMs && shoots.size() < 2){
                float sx = rnd.nextFloat()*w*0.7f;
                float sy = rnd.nextFloat()*h*0.3f;
                float sp = (w*0.5f + rnd.nextFloat()*w*0.4f);
                shoots.add(new Shoot(sx, sy, sp, sp*0.45f, nowMs, 700 + (long)(rnd.nextFloat()*400)));
                nextShootMs = nowMs + 7000 + (long)(rnd.nextFloat()*9000);
            }
            for (int i = shoots.size()-1; i >= 0; i--){
                Shoot s = shoots.get(i);
                long age = nowMs - s.born;
                if (age > s.life){ shoots.remove(i); continue; }
                float f = age/(float)s.life;
                float cx = s.x0 + s.vx*age/1000f;
                float cy = s.y0 + s.vy*age/1000f;
                float tx = cx - s.vx*0.12f;
                float ty = cy - s.vy*0.12f;
                shoot.setAlpha((int)((1f-f)*220f));
                c.drawLine(tx, ty, cx, cy, shoot);
            }
            shoot.setAlpha(255);
        } else if (!animated) {
            shoots.clear();
        }
    }

    private void drawForeground(Canvas c, int w, int h, float daylight, float sunX, float horizonY, int sunCol){
        int fCol = SunTheme.lerpColor(SunTheme.nightFar(theme), SunTheme.dayFar(theme), daylight);
        int nCol = SunTheme.lerpColor(SunTheme.nightNear(theme), SunTheme.dayNear(theme), daylight);
        int st = SunTheme.scene(theme);

        if (st == SunTheme.SCENE_HILLS || st == SunTheme.SCENE_DUNES){
            far.setColor(fCol);  c.drawPath(farPath, far);
            near.setColor(nCol); c.drawPath(nearPath, near);
            return;
        }
        if (st == SunTheme.SCENE_SEA){
            far.setColor(fCol);
            c.drawRect(0, horizonY, w, horizonY + (h-horizonY)*0.45f, far);
            near.setColor(nCol);
            c.drawRect(0, horizonY + (h-horizonY)*0.45f, w, h, near);
            float bw = Math.min(w,h)*0.10f;
            int ga = (int)(Math.max(0f, daylight)*150f);
            glint.setShader(new RadialGradient(sunX, horizonY, (h-horizonY)*0.9f,
                    new int[]{withAlpha(sunCol, ga/255f), 0x00000000},
                    new float[]{0f,1f}, Shader.TileMode.CLAMP));
            c.drawRect(sunX-bw*2, horizonY, sunX+bw*2, h, glint);
            water.setColor(0x22FFFFFF);
            for (int i=0;i<5;i++){
                float y = horizonY + (h-horizonY)*(0.2f + i*0.16f);
                c.drawRect(w*0.1f, y, w*0.9f, y+1.5f, water);
            }
            return;
        }
        // ICE
        near.setColor(nCol);
        c.drawRect(0, horizonY, w, h, near);
        far.setColor(fCol);
        for (int i=0;i<spikeCount;i++){
            float x = spikes[i*3], sw = spikes[i*3+1], sh = spikes[i*3+2];
            Path p = new Path();
            p.moveTo(x, horizonY+2f);
            p.lineTo(x+sw/2f, horizonY - sh);
            p.lineTo(x+sw, horizonY+2f);
            p.close();
            c.drawPath(p, far);
        }
    }

    private static int withAlpha(int color, float scale){
        scale = Math.max(0f, Math.min(1f, scale));
        return Color.argb((int)(Color.alpha(color)*scale),
                Color.red(color), Color.green(color), Color.blue(color));
    }
}
EOF

echo "gen11: OK"
