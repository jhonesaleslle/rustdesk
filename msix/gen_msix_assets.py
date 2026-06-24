#!/usr/bin/env python3
# msix/gen_msix_assets.py
# Gera os assets/ícones que a Microsoft Store / MSIX exigem, a partir da logo
# Tecnovetti commitada (res/icon.png, 512x512 RGBA — tecnovetti-master.png NÃO
# entra no git por causa do *.png no .gitignore).
#
# Uso:  python gen_msix_assets.py <logo_origem.png> <pasta_destino_Assets>
#
# Gera só os nomes-base no scale-100 (sem variantes .scale-/.targetsize-): é o
# conjunto mínimo que o makeappx empacota SEM precisar de makepri/resources.pri,
# o que mantém o passo do CI à prova de falha. Para os assets quadrados a logo é
# redimensionada; para o tile largo e o splash a logo é centralizada num canvas
# transparente (não temos versão horizontal da marca).
import sys
from PIL import Image

# (arquivo, largura, altura) — tamanhos scale-100 padrão de MSIX/Store.
SQUARE = [
    ("StoreLogo.png", 50, 50),         # Store / Properties/Logo
    ("Square44x44Logo.png", 44, 44),   # lista de apps, barra de tarefas, título
    ("Square71x71Logo.png", 71, 71),   # tile pequeno
    ("Square150x150Logo.png", 150, 150),  # tile médio (obrigatório)
    ("Square310x310Logo.png", 310, 310),  # tile grande
]
WIDE = [
    ("Wide310x150Logo.png", 310, 150),  # tile largo
    ("SplashScreen.png", 620, 300),     # tela de abertura
]


def fit_square(src, size):
    return src.resize((size, size), Image.LANCZOS)


def fit_centered(src, w, h):
    # logo proporcional, centralizada em canvas transparente w x h
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    side = int(min(w, h) * 0.85)
    logo = src.resize((side, side), Image.LANCZOS)
    canvas.paste(logo, ((w - side) // 2, (h - side) // 2), logo)
    return canvas


def main():
    if len(sys.argv) != 3:
        print("uso: gen_msix_assets.py <logo.png> <dest_Assets>", file=sys.stderr)
        sys.exit(2)
    src_path, dest = sys.argv[1], sys.argv[2]
    src = Image.open(src_path).convert("RGBA")
    for name, w, h in SQUARE:
        fit_square(src, w).save(f"{dest}/{name}", format="PNG")
        print(f"  {name} {w}x{h}")
    for name, w, h in WIDE:
        fit_centered(src, w, h).save(f"{dest}/{name}", format="PNG")
        print(f"  {name} {w}x{h}")
    print("assets MSIX gerados em", dest)


if __name__ == "__main__":
    main()
