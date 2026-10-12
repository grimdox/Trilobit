#!/usr/bin/env python3
"""Generate 10,000 unique NPC names for Trilobit: ~70% Japanese, ~15% Russian, ~15% Chinese.
Deterministic (seeded).  Output: names/npc_names_10000.{txt,csv,json}
usage: gen_names.py <output dir>"""
import csv, json, os, random, sys
OUT = sys.argv[1] if len(sys.argv) > 1 else "names"
rng = random.Random(1868)

# ------------------------------------------------------------------ Japanese (family name, given names; Heian to Showa usage)
JP_FAMILY = """Abe Akamatsu Akechi Akiyama Amano Anan Ando Aoki Arai Arakawa Arima Asai Asakura Asano Ashikaga Baba Chiba Date Doi Egawa
Endo Eto Fujii Fujikawa Fujimori Fujimoto Fujisawa Fujita Fujiwara Fukuda Fukui Fukushima Fukuzawa Furuta Gamo Goto Hachisuka Hamada
Hanabusa Hara Harada Hasegawa Hashimoto Hata Hatakeyama Hattori Hayashi Hida Higa Higashi Hino Hirai Hirano Hirata Hirose Hiraoka
Hirota Hiroshima Hojo Honda Hori Horie Hoshino Hosokawa Ichijo Ichikawa Ida Igarashi Iida Iijima Ikeda Ikegami Imai Imagawa Inaba
Inagaki Ino Inoue Inukai Ishibashi Ishida Ishihara Ishii Ishikawa Ishimaru Isobe Itagaki Ito Iwai Iwamoto Iwasaki Iwata Izumi Jinbo
Kagawa Kaji Kajiwara Kamei Kamiya Kanda Kanemoto Kanno Kasai Kashiwagi Kataoka Katayama Kato Katsura Kawabata Kawada Kawaguchi
Kawai Kawakami Kawamura Kawano Kawasaki Kawashima Kikuchi Kimura Kinoshita Kishi Kitagawa Kitamura Kitano Kobayashi Koda Koga
Koide Koike Koizumi Kojima Kondo Konishi Kono Kosugi Kubo Kudo Kumagai Kuno Kuramochi Kurata Kuribayashi Kuroda Kurogane
Kurosawa Kusunoki Kuwabara Machida Maeda Maki Makino Masuda Matsubara Matsuda Matsui Matsukata Matsumoto Matsunaga Matsuo
Matsuoka Matsushita Matsuura Mazaki Mihara Miki Minami Minamoto Minato Mishima Mita Mito Miura Miyake Miyamoto Miyazaki Miyoshi
Mizuno Mochizuki Mori Morimoto Morioka Morita Moriya Motoori Murai Murakami Murata Muto Nabeshima Nagai Nagano Nagao Nagata
Nagumo Naito Nakagawa Nakai Nakajima Nakamura Nakane Nakano Nakao Nakashima Nakata Nakayama Narita Natsume Niimi Nishi Nishida
Nishikawa Nishimura Nishio Nitta Noda Nogi Nomura Nonaka Noro Obata Oda Odagiri Ogasawara Ogawa Ogura Ohara Oishi Oka Okada
Okamoto Okano Okubo Okuda Omori Omura Onishi Ono Osaka Oshima Ota Otsuka Otsuki Ozaki Ozawa Rokkaku Saeki Saga Saigo Saito Sakai
Sakaki Sakamoto Sakata Sakurai Sakuma Sanada Sano Sasaki Sato Sawada Segawa Seki Sekine Shibata Shiga Shimada Shimazu Shimizu
Shimura Shinagawa Shindo Shinohara Shirai Shiraishi Shirakawa Shoji Soga Sone Sono Soma Sudo Sugawara Sugimoto Sugiyama Sumida
Suzuki Tachibana Tada Tagawa Taira Takagi Takahashi Takai Takano Takasaki Takashima Takayama Takeda Takei Takemoto Takenaka
Takeuchi Takeshita Tamura Tanabe Tanaka Tani Taniguchi Tashiro Tateishi Terada Terauchi Toda Togo Tojo Tokugawa Tomita Tomonaga
Toyama Toyoda Toyotomi Tsuboi Tsuchiya Tsuda Tsukamoto Tsukuda Tsutsui Uchida Uchiyama Ueda Uehara Uesugi Ueno Umeda Uno
Urabe Ushijima Utsunomiya Wada Wakabayashi Wakamatsu Watanabe Yagi Yamada Yamagata Yamaguchi Yamaji Yamamoto Yamamura Yamanaka
Yamasaki Yamashita Yamauchi Yamazaki Yanagi Yanagida Yasuda Yokoi Yokota Yokoyama Yoshida Yoshikawa Yoshimura Yoshino Yuasa
Yuki Zenda""".split()
JP_MALE = """Akihiro Akira Atsushi Daichi Daisuke Eiji Fumio Genji Goro Haruki Haruo Hayato Hideaki Hidekazu Hideki Hidetaka Hideyoshi
Hikaru Hiroki Hiroshi Hisashi Hitoshi Isamu Ishiro Jiro Jun Junichi Kaito Kaname Katsu Katsuo Katsuya Kazuhiko Kazuki Kazuo
Kazuya Keiichi Keiji Keita Kenichi Kenji Kenjiro Kenta Kenzo Kichiro Kiyoshi Kohei Koji Kosuke Kouki Kunio Kyoji Makoto Manabu
Masaaki Masahiro Masaki Masanobu Masao Masashi Masato Masayuki Michio Mikio Minoru Mitsuo Mitsuru Mototsugu Nagato Naoki Naoto
Nobuo Nobuyuki Noboru Osamu Rei Reiji Rikuo Rokuro Ryo Ryohei Ryoichi Ryota Ryuji Ryunosuke Saburo Satoru Seiji Seiichi Shigeru
Shingo Shinichi Shinji Shiro Shizuo Shohei Shota Shozo Shuhei Shunichi Shunsuke Sora Sota Susumu Tadao Tadashi Takahiro Takashi
Takeo Takeru Takeshi Takuma Takumi Takuya Tarou Tatsuo Tatsuya Teruo Tetsu Tetsuo Tetsuya Toshiaki Toshio Toshiro Tsuyoshi Wataru
Yasuhiro Yasuo Yasushi Yoichi Yori Yoshiaki Yoshio Yoshiro Yoshitaka Yosuke Yuji Yukio Yusuke Yuta Yuto Zenjiro""".split()
JP_FEMALE = """Aiko Akane Akemi Aki Ami Ayaka Ayame Ayano Azusa Chie Chieko Chiharu Chika Chikage Emi Emiko Eri Fumiko Fusae Haruka Haruko
Harue Hatsue Hideko Hikari Hina Hinata Hisako Hitomi Hotaru Ichika Izumi Junko Kaede Kana Kanako Kaori Kaoru Kasumi Katsuko
Kayo Keiko Kimiko Kiyoko Kokoro Kotoko Kumiko Kyoko Machiko Madoka Mai Maki Makiko Mana Mariko Masako Mayumi Megumi Michiko
Midori Mieko Mika Miki Mikuru Minako Mio Misaki Mitsuko Miyako Miyuki Momoko Moe Mutsuko Nagisa Nanako Naoko Natsuko Natsumi
Noriko Nozomi Reiko Rie Rieko Rika Rin Rina Rinko Ritsuko Rumi Ryoko Sachiko Sadako Saeko Sakura Sanae Satoko Satomi Sawako
Sayuri Setsuko Shigeko Shino Shinobu Shizuka Sumiko Suzuko Taeko Takako Tamako Tomoko Toshiko Tsubaki Tsukiko Ume Utako Wakana
Yasuko Yayoi Yoko Yoshiko Yui Yuka Yukari Yukiko Yumi Yumiko Yuna Yuriko Yuzuki""".split()

# ------------------------------------------------------------------ Russian (surnames in masculine/feminine form, given names, patronymic stems)
RU_SURNAME = """Alekseev Andreev Antonov Arkhipov Baranov Belov Bobrov Bogdanov Borisov Chernov Chernyshev Denisov Dmitriev Egorov Efimov
Fedorov Filippov Frolov Gavrilov Golubev Gromov Grigoriev Ignatov Ilyin Ivanov Kalinin Karpov Kazakov Kirillov Kiselev Kolesnikov
Komarov Konovalov Korolev Kostin Kozlov Krasnov Kruglov Kuzmin Kuznetsov Lazarev Lebedev Leontiev Lipatov Lobanov Lukin Maksimov
Malinin Maslov Medvedev Melnikov Mikhailov Morozov Naumov Nikitin Nikolaev Orlov Osipov Panov Pavlov Petrov Pletnev Polyakov
Popov Prokhorov Romanov Rozhkov Sablin Safonov Sakharov Savelyev Semenov Serov Shestakov Shubin Smirnov Sokolov Solovyov Stepanov
Sukhanov Tarasov Titov Trofimov Ushakov Vasiliev Volkov Voronin Vlasov Yakovlev Yermolov Zaitsev Zakharov Zhdanov Zhukov Zinoviev""".split()
RU_MALE = """Aleksandr Aleksei Anatoly Andrei Anton Arkady Artem Boris Daniil Denis Dmitri Evgeny Fyodor Gennady Georgy Gleb Grigory Igor
Ilya Ivan Konstantin Kirill Lev Leonid Maksim Mikhail Nikita Nikolai Oleg Pavel Pyotr Roman Ruslan Semyon Sergei Stanislav
Stepan Timofei Vadim Valentin Valery Vasily Viktor Vitaly Vladimir Vladislav Vsevolod Vyacheslav Yakov Yaroslav Yuri Zakhar""".split()
RU_FEMALE = """Aleksandra Alina Anastasia Anna Antonina Valentina Vera Darya Ekaterina Elena Elizaveta Evgenia Galina Inessa Irina Klavdia
Kseniya Larisa Lidia Lyubov Lyudmila Margarita Maria Marina Nadezhda Natalia Nina Olga Polina Raisa Svetlana Sofia Tamara
Tatiana Tonya Ulyana Valeria Varvara Vasilisa Yana Yelizaveta Yulia Zinaida Zoya""".split()
RU_PATRONYM_STEM = ["Aleksandr", "Aleksei", "Andrei", "Anatol", "Boris", "Dmitri", "Fyodor", "Gennad", "Grigor", "Igor", "Ivan", "Konstantin",
                    "Leonid", "Maksim", "Mikhail", "Nikolai", "Oleg", "Pavel", "Pyotr", "Sergei", "Viktor", "Vladimir", "Yuri"]
PAT = {"Aleksandr": "Aleksandrov", "Aleksei": "Alekseev", "Andrei": "Andreev", "Anatol": "Anatolev", "Boris": "Borisov", "Dmitri": "Dmitriev",
       "Fyodor": "Fyodorov", "Gennad": "Gennadiev", "Grigor": "Grigoriev", "Igor": "Igorev", "Ivan": "Ivanov", "Konstantin": "Konstantinov",
       "Leonid": "Leonidov", "Maksim": "Maksimov", "Mikhail": "Mikhailov", "Nikolai": "Nikolaev", "Oleg": "Olegov", "Pavel": "Pavlov",
       "Pyotr": "Petrov", "Sergei": "Sergeev", "Viktor": "Viktorov", "Vladimir": "Vladimirov", "Yuri": "Yurev"}
def patronymic(stem, female):
    b = PAT[stem]
    # Ivanov -> Ivanovich/Ivanovna; Alekseev -> Alekseevich/Alekseevna; Igorev -> Igorevich
    return b + ("na" if female else "ich") if b.endswith(("ov", "ev")) else b
def ru_fem_surname(s):
    if s.endswith("sky"): return s[:-1] + "aya"
    if s.endswith(("ov", "ev", "in", "yn")): return s + "a"
    if s.endswith("iy"): return s[:-2] + "aya"
    return s

# ------------------------------------------------------------------ Chinese (family name, given-name syllables; pinyin)
CN_FAMILY = """Bai Cai Cao Chang Chen Cheng Dai Deng Ding Dong Du Duan Fan Fang Feng Fu Gao Gong Gu Guan Guo Han He Hong Hou Hu Huang Jia
Jiang Jin Kong Lai Lei Li Liang Lin Liu Long Lu Luo Ma Mao Meng Mo Pan Peng Qian Qin Qiu Ren Shao Shen Shi Song Su Sun Tan Tang
Tao Tian Wan Wang Wei Wen Wu Xia Xiang Xiao Xie Xu Xue Yan Yang Yao Ye Yin Yu Yuan Zeng Zhang Zhao Zheng Zhong Zhou Zhu Zhuang
Zou""".split()
CN_SYL_M = """Bao Bin Bo Chao Chen Cheng Da Dong Fei Feng Gang Guang Guo Hai Hao Hong Hua Jian Jie Jun Kai Lei Liang Lin Ming Peng Qiang
Rui Shan Sheng Tao Wei Xiang Xin Xiong Yang Yi Yong Yu Yuan Zhen Zhi Zhong""".split()
CN_SYL_F = """Ai Bing Chun Dan Fang Fen Hui Jia Jing Juan Li Lan Lian Lin Ling Mei Min Na Ning Qian Qing Rong Shu Ting Wen Xia Xiao Xue
Yan Yin Ying Yu Yun Zhen Zhi""".split()

def jp(female):
    f = rng.choice(JP_FAMILY); g = rng.choice(JP_FEMALE if female else JP_MALE)
    return f"{g} {f}", "JP"
def ru(female):
    s = rng.choice(RU_SURNAME); g = rng.choice(RU_FEMALE if female else RU_MALE)
    pat = patronymic(rng.choice(RU_PATRONYM_STEM), female)
    if female: s = ru_fem_surname(s)
    return (f"{g} {pat} {s}" if rng.random() < 0.4 else f"{g} {s}"), "RU"
def cn(female):
    f = rng.choice(CN_FAMILY)
    pool = CN_SYL_F if female else CN_SYL_M
    if rng.random() < 0.6:
        a = rng.choice(pool); b = rng.choice(pool + (CN_SYL_M if female else CN_SYL_F) if rng.random() < 0.3 else pool)
        g = (a + b.lower()) if a != b else a
    else:
        g = rng.choice(pool)
    return f"{f} {g}", "CN"

N = 10000
mix = [("JP", 0.70), ("RU", 0.15), ("CN", 0.15)]
want = {k: round(N * p) for k, p in mix}
rows, seen = [], set()
for origin, fn in (("JP", jp), ("RU", ru), ("CN", cn)):
    n = 0
    while n < want[origin]:
        female = rng.random() < 0.5
        name, o = fn(female)
        if name in seen: continue
        seen.add(name); rows.append((name, o, "F" if female else "M")); n += 1
rng.shuffle(rows)
assert len(rows) == N, len(rows)
os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "npc_names_10000.txt"), "w") as f:
    f.write("\n".join(r[0] for r in rows) + "\n")
with open(os.path.join(OUT, "npc_names_10000.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["name", "origin", "gender"]); w.writerows(rows)
json.dump([{"name": n, "origin": o, "gender": g} for n, o, g in rows], open(os.path.join(OUT, "npc_names_10000.json"), "w"), ensure_ascii=False)
print(len(rows), {k: sum(1 for r in rows if r[1] == k) for k in want}, "unique:", len(seen))
