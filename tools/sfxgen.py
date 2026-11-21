# -*- coding: utf-8 -*-
"""
sfxgen.py — 程序化音效生成（纯 numpy，输出 16bit 44.1kHz mono WAV）
《沈家老宅》：雨/风/滴水/吱呀/门响/唢呐/二胡/梆子/铜铃/心跳/灯芯爆裂/戏曲念白抽象化 …
"""
import os, wave, math
import numpy as np

SR = 44100
rng = np.random.default_rng(0x9B5)

# ---------------------------------------------------------------- 基础
def t(dur):
    return np.arange(int(SR * dur)) / SR

def sine(freq, dur, ph=0.0):
    tt = t(dur)
    f = freq(tt) if callable(freq) else freq
    return np.sin(2 * np.pi * f * tt + ph)

def noise(dur, color="white"):
    n = rng.standard_normal(int(SR * dur)).astype(np.float32)
    if color == "brown":
        n = np.cumsum(n); n -= np.linspace(n[0], n[-1], len(n)); n /= (np.abs(n).max() + 1e-9)
    return n * 0.3

def env_adsr(n, a=0.01, d=0.1, s=0.6, r=0.2):
    """简单包络（秒）"""
    total = len(n) / SR
    e = np.ones(len(n), dtype=np.float32) * s
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = min(ai, len(n))
    di = min(di, len(n) - ai)
    e[:ai] = np.linspace(0, 1, ai)
    if di > ai:
        e[ai:ai + di] = np.linspace(1, s, di)
    if ri > 0:
        e[-ri:] *= np.linspace(1, 0, ri)
    return n * e

def fft_filt(x, curve, sr=SR):
    """curve: [(freq, gain_dB)] 折线插值滤波"""
    X = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1 / sr)
    cf = np.array([c[0] for c in curve], dtype=np.float64)
    cg = np.array([c[1] for c in curve], dtype=np.float64)
    gain = 10 ** (np.interp(freqs, cf, cg) / 20)
    y = np.fft.irfft(X * gain, len(x))
    mx = np.abs(y).max() + 1e-9
    return (y / mx * (np.abs(x).max() + 1e-9)).astype(np.float32)

def normalize(x, peak=0.85):
    m = np.abs(x).max() + 1e-9
    return (x / m * peak).astype(np.float32)

def fade_edges(x, ms=8):
    n = int(SR * ms / 1000)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x

def loopify(x, cross_s=0.5):
    """首尾交叉混合做成无缝循环"""
    n = int(SR * cross_s)
    head, tail = x[:n].copy(), x[-n:].copy()
    w = np.linspace(0, 1, n).astype(np.float32)
    x[-n:] = tail * w + head * (1 - w)
    return x[:-n]


def mix_at(dst, src, pos_s, gain=1.0):
    """在 dst 的 pos_s 秒处叠加 src（自动裁剪越界）"""
    p = int(pos_s * SR)
    n = min(len(src), len(dst) - p)
    if n > 0:
        dst[p:p + n] += src[:n] * gain
    return dst

def save(path, x, peak=0.85):
    x = normalize(np.asarray(x, dtype=np.float32), peak)
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return path

# ---------------------------------------------------------------- 音色
def thump(freq=55, dur=0.35, bend=0.5):
    """低频鼓点/心跳单元"""
    tt = t(dur)
    f = freq * (1 - bend * tt / dur)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR)
    x *= np.exp(-tt * 14)
    return x

def woodblock(freq=820, dur=0.09):
    tt = t(dur)
    x = np.sin(2 * np.pi * freq * tt) * np.exp(-tt * 60)
    x += noise(dur) * np.exp(-tt * 90) * 0.8
    return x

def bell_hit(base=660, dur=2.4):
    tt = t(dur)
    x = np.zeros(len(tt), dtype=np.float32)
    for i, (h, amp, dec) in enumerate([(1, 1.0, 2.2), (2.0, 0.55, 3.0), (3.01, 0.30, 3.6), (4.2, 0.18, 4.5)]):
        x += amp * np.sin(2 * np.pi * base * h * tt + i) * np.exp(-tt * dec)
    x += noise(dur) * np.exp(-tt * 80) * 0.25
    return x

def saw(freq, dur):
    tt = t(dur)
    f = freq(tt) if callable(freq) else np.full(len(tt), freq, dtype=np.float32)
    ph = np.cumsum(f) / SR
    return (2 * (ph % 1) - 1).astype(np.float32)

def vibrato(x, rate=5.5, depth=0.02):
    tt = np.arange(len(x)) / SR
    d = depth * np.sin(2 * np.pi * rate * tt) * SR  # 采样延迟
    idx = np.clip(np.arange(len(x))[:, None] + np.int32(np.zeros((1, 2))), 0, len(x) - 1)
    out = np.copy(x)
    # 简化：正弦调频近似 = x * (1 + depth*mod)
    out = x * (1 + depth * np.sin(2 * np.pi * rate * tt))
    return out.astype(np.float32)

def crackle_burst(n_bursts=9, dur=0.9):
    x = np.zeros(int(SR * dur), dtype=np.float32)
    for _ in range(n_bursts):
        p = rng.integers(0, len(x) - 200)
        ln = rng.integers(40, 160)
        x[p:p + ln] += rng.standard_normal(ln) * rng.uniform(0.4, 1.0)
    return fft_filt(x, [(100, -6), (900, 0), (4000, -2), (9000, -14)])

# ---------------------------------------------------------------- 具体音效
def build_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    S = lambda name, x, peak=0.85: save(os.path.join(out_dir, name + ".wav"), x, peak)

    # ---- 环境循环 ----
    rain = fft_filt(noise(8), [(60, -20), (400, -4), (1600, 0), (5200, -3), (9000, -10)])
    drop_t = np.zeros(len(rain), dtype=np.float32)
    for _ in range(90):
        p = rng.integers(0, len(drop_t) - 2000)
        f0 = rng.uniform(2000, 5200)
        tt2 = t(0.02)
        drop_t[p:p + len(tt2)] += np.sin(2 * np.pi * f0 * tt2) * np.exp(-tt2 * 300) * 0.4
    S("amb_rain_loop", loopify(fade_edges(rain * 0.9 + drop_t)))
    wind = fft_filt(noise(8, "brown"), [(40, -8), (150, 0), (600, -6), (2500, -18)])
    lfo = 0.55 + 0.45 * np.sin(2 * np.pi * np.arange(len(wind)) / SR * 0.13)
    S("amb_wind_loop", loopify(fade_edges(wind * lfo)))
    cave = fft_filt(noise(6, "brown"), [(30, -12), (120, 0), (500, -12), (2000, -26)])
    S("amb_room_tone", loopify(fade_edges(cave)))
    fire = fft_filt(noise(5), [(50, -16), (300, -2), (1200, 0), (6000, -8)])
    pops = crackle_burst(70, 5)
    S("fire_crackle_loop", loopify(fade_edges(fire * 0.6 + pops * 0.7)))
    ghost_breath = fft_filt(noise(6), [(80, -10), (250, 0), (700, -6), (1800, -20)])
    g_lfo = 0.5 + 0.5 * np.sin(2 * np.pi * np.arange(len(ghost_breath)) / SR * 0.35 - 1)
    S("amb_ghost_breath_loop", loopify(fade_edges(ghost_breath * (0.4 + 0.6 * g_lfo))))

    # ---- 单发音效 ----
    tt = t(2.0)
    drip = np.sin(2 * np.pi * (900 - 400 * tt / 2) * tt) * np.exp(-tt * 9)
    drip[:int(0.003 * SR)] += noise(0.003) * 2
    echo = np.zeros(int(2.6 * SR), dtype=np.float32)
    echo[:len(drip)] += drip
    for dl, g in [(0.33, 0.5), (0.71, 0.28), (1.15, 0.15)]:
        mix_at(echo, drip, dl, g)
    S("drip_well", echo)

    creak = saw(lambda tt: 95 - 30 * tt / 1.4, 1.4)
    creak = fft_filt(creak, [(60, -10), (200, 0), (900, -4), (3000, -16)])
    wob = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(len(creak)) / SR * 7.3)
    S("creak_wood", fade_edges(creak * wob))

    bang = np.zeros(int(1.0 * SR), dtype=np.float32)
    tt = t(0.5)
    b = fft_filt(noise(0.5), [(60, -4), (180, 0), (900, -8), (3000, -20)]) * np.exp(-tt * 18)
    mix_at(bang, b, 0, 1.2)
    mix_at(bang, thump(70, 0.5, 0.6), 0, 0.9)
    S("door_bang", fade_edges(bang))

    roll = np.zeros(int(1.5 * SR), dtype=np.float32)
    tt2 = t(0.03)
    for i in range(26):
        mix_at(roll, np.sin(2 * np.pi * (300 - i * 6) * tt2) * np.exp(-tt2 * 120) * 0.6, 0.05 * i * rng.uniform(0.7, 1.3))
    roll += fft_filt(noise(1.5), [(300, -10), (900, 0), (2500, -6)]) * 0.15
    S("drawer_roll", fade_edges(roll))

    sq = np.zeros(int(1.0 * SR), dtype=np.float32)
    for i, st in enumerate([0.0, 0.22, 0.5]):
        tt2 = t(0.18)
        f = 2400 + i * 250
        chirp = np.sin(2 * np.pi * (f + 700 * tt2 / 0.18) * tt2) * np.exp(-tt2 * 20)
        mix_at(sq, chirp, st, 0.8)
    S("rat_squeak", fade_edges(sq))

    br = fft_filt(noise(0.9), [(150, -8), (500, 0), (1200, -4), (3000, -14)])
    be = env_adsr(br, 0.15, 0.2, 0.7, 0.35)
    S("breath_short", be)

    sigh_t = t(2.2)
    tone = np.sin(2 * np.pi * np.cumsum(300 - 120 * sigh_t / 2.2) / SR) * 0.35
    tone *= np.exp(-((sigh_t - 1.0) ** 2) / 0.5)
    airy = fft_filt(noise(2.2), [(200, -6), (600, 0), (1400, -6)]) * env_adsr(noise(2.2) * 0 + np.ones(int(2.2 * SR)), 0.4, 0.5, 0.8, 0.7) * 0.5
    S("sigh_woman", tone + airy)

    # 戏曲念白抽象化：带颤音的滑行假声
    op_t = t(1.8)
    f = np.where(op_t < 0.7, 620 + 80 * op_t / 0.7, 700 - 180 * (op_t - 0.7) / 1.1)
    vib = 1 + 0.06 * np.sin(2 * np.pi * 6.5 * op_t)
    op = np.sin(2 * np.pi * np.cumsum(f * vib) / SR)
    op += 0.4 * np.sin(2 * np.pi * np.cumsum(2.02 * f * vib) / SR)
    op = env_adsr(op, 0.12, 0.2, 0.85, 0.4)
    op = fft_filt(op, [(200, -10), (700, 0), (2000, -3), (4500, -12)])
    S("opera_voice", fade_edges(op))

    # 唢呐
    sn_t = t(1.4)
    f = 520 + 60 * np.clip(sn_t / 0.25, 0, 1) - 40 * np.clip((sn_t - 1.0) / 0.4, 0, 1)
    sn = saw(lambda tt: np.interp(tt, sn_t, f), 1.4)
    for h, a in [(2, 0.5), (3, 0.35), (4, 0.2)]:
        sn = sn + a * saw(lambda tt, h=h: np.interp(tt, sn_t, f) * h, 1.4)
    sn = env_adsr(sn, 0.03, 0.15, 0.9, 0.25)
    sn = fft_filt(sn, [(300, -6), (1000, 0), (2600, -2), (6000, -14)])
    S("suona_short", fade_edges(sn))
    sn2_t = t(2.8)
    f2 = 460 + 40 * np.sin(2 * np.pi * 1.2 * sn2_t)
    sn2 = saw(lambda tt: np.interp(tt, sn2_t, f2), 2.8)
    sn2 += 0.5 * saw(lambda tt: np.interp(tt, sn2_t, f2) * 2.0, 2.8)
    sn2 = vibrato(sn2, 5.0, 0.05)
    sn2 = env_adsr(sn2, 0.15, 0.4, 0.9, 0.6)
    sn2 = fft_filt(sn2, [(300, -6), (1000, 0), (2600, -2), (6000, -14)])
    S("suona_long", fade_edges(sn2))

    # 二胡滑音
    eh_t = t(1.6)
    fe = np.interp(eh_t, [0, 1.6], [430, 210])
    eh = np.sin(2 * np.pi * np.cumsum(fe) / SR)
    eh = vibrato(eh, 6.0, 0.045)
    eh += fft_filt(noise(1.6), [(800, -14), (1800, 0), (3200, -8)]) * 0.08  # 弓弦噪
    eh = env_adsr(eh, 0.2, 0.3, 0.8, 0.5)
    S("erhu_slide", fade_edges(eh))

    S("bangzi", woodblock(820, 0.09))
    S("bangzi_far", fft_filt(woodblock(700, 0.12), [(200, -6), (600, 0), (2000, -10)]) * 0.7)

    S("bell_single", bell_hit(660))
    S("bell_deep", bell_hit(330, 3.0))
    hb = np.zeros(int(1.3 * SR), dtype=np.float32)
    mix_at(hb, thump(52, 0.3), 0, 1.0)
    mix_at(hb, thump(48, 0.35), 0.28, 0.85)
    S("heartbeat", hb)

    for i in range(2):
        st = fft_filt(noise(0.16), [(80, -8), (250, 0), (800, -4), (2400, -14)])
        st[:len(thump(120, 0.12))] += thump(120, 0.12) * 0.7
        S("step_wood_%d" % (i + 1), fade_edges(st * rng.uniform(0.8, 1.0)))

    S("wick_crackle", crackle_burst(10, 1.0))
    whoosh = fft_filt(noise(0.8), [(100, -14), (400, -4), (900, 0), (2400, -6)])
    S("lantern_relight", fade_edges(env_adsr(whoosh, 0.05, 0.2, 0.7, 0.3)))

    wh = fft_filt(noise(1.8), [(300, -10), (900, 0), (1600, -2), (3200, -12)])
    form = 1 + 0.5 * np.sin(2 * np.pi * 2.2 * t(1.8))
    S("whisper", fade_edges(env_adsr(wh * form, 0.3, 0.4, 0.7, 0.5)))

    fl = noise(0.35)
    S("paper_flip", fade_edges(fft_filt(fl, [(400, -12), (1500, 0), (3600, -3), (7000, -12)])))

    click = np.zeros(int(0.5 * SR), dtype=np.float32)
    tt2 = t(0.1)
    c1 = np.sin(2 * np.pi * 1800 * tt2) * np.exp(-tt2 * 90) + np.sin(2 * np.pi * 900 * tt2) * np.exp(-tt2 * 70)
    mix_at(click, c1, 0, 1.0)
    c2 = np.sin(2 * np.pi * 1200 * tt2) * np.exp(-tt2 * 60)
    mix_at(click, c2, 0.22, 0.8)
    S("unlock_click", fade_edges(click))

    ch = np.zeros(int(2.2 * SR), dtype=np.float32)
    for f0, dl in [(659, 0.0), (784, 0.18), (988, 0.36), (1319, 0.54)]:
        mix_at(ch, bell_hit(f0, 1.6) * 0.7, dl)
    S("puzzle_success", fade_edges(ch))

    dis_t = t(1.0)
    dis = np.sin(2 * np.pi * 110 * dis_t) + np.sin(2 * np.pi * 116.5 * dis_t) + np.sin(2 * np.pi * 164 * dis_t) * 0.5
    S("puzzle_fail", fade_edges(env_adsr(dis, 0.02, 0.3, 0.7, 0.3)))

    th_t = t(2.6)
    rum = fft_filt(noise(2.6, "brown"), [(30, -6), (90, 0), (300, -10), (1200, -24)])
    rum *= np.exp(-th_t * 1.8)
    S("thunder", fade_edges(rum))

    # ---- 音乐 ----
    # 菜单/氛围 drones（10s 无缝）
    dr_t = t(10)
    drone = (np.sin(2 * np.pi * 55 * dr_t) + np.sin(2 * np.pi * 55.7 * dr_t)
             + 0.5 * np.sin(2 * np.pi * 110.3 * dr_t) + 0.35 * np.sin(2 * np.pi * 164.8 * dr_t))
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * dr_t + 1)
    drone = fft_filt(drone * trem, [(40, -8), (80, 0), (300, -6), (1200, -20)])
    bell_motif = np.zeros(len(dr_t), dtype=np.float32)
    for dl, f0 in [(2.0, 659), (5.5, 587), (8.2, 523)]:
        mix_at(bell_motif, bell_hit(f0, 2.0) * 0.25, dl)
    S("music_drone_loop", loopify(fade_edges(drone * 0.8 + bell_motif)))

    # 追逐循环（9.6s = 96bpm 4小节）
    ch_len = int(9.6 * SR)
    chase = np.zeros(ch_len, dtype=np.float32)
    bpm = 96
    beat = 60 / bpm
    for b in range(16):
        p = b * beat
        mix_at(chase, thump(58, 0.3, 0.5), p, 1.0 if b % 4 == 0 else 0.6)
        mix_at(chase, woodblock(900, 0.06), p + beat * 0.5, 0.4)
    # 紧急音型（五声小调）
    notes = [220, 261.6, 293.7, 246.9, 220]
    for i, f0 in enumerate(notes * 3):
        nt = saw(f0, beat * 0.9) * 0.35
        nt = fft_filt(nt, [(200, -8), (440, 0), (1500, -8)])
        nt = env_adsr(nt, 0.01, 0.1, 0.6, 0.1)
        mix_at(chase, nt, i * beat, 0.5)
    S("music_chase_loop", loopify(fade_edges(chase)))

    # 结局·暖（少用，收束）
    ed_t = t(8)
    ed = (np.sin(2 * np.pi * 261.6 * ed_t) + 0.6 * np.sin(2 * np.pi * 392 * ed_t)
          + 0.4 * np.sin(2 * np.pi * 523.2 * ed_t))
    ed = fft_filt(ed, [(100, -10), (300, 0), (1200, -10)])
    ed *= (0.6 + 0.4 * np.sin(2 * np.pi * 0.2 * ed_t))
    S("music_ending_warm", loopify(fade_edges(env_adsr(ed, 1.0, 0.5, 0.85, 1.2))))

    print("[sfxgen] 音效完成: %d 个" % len(os.listdir(out_dir)))


if __name__ == "__main__":
    import sys
    build_all(sys.argv[1] if len(sys.argv) > 1 else "../assets/sfx")
