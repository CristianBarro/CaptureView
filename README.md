# CaptureView

Visualizador nativo para placas de captura USB (UVC) no Windows: vídeo até 1080p60 com áudio, baixa latência, e efeitos na GPU para transmitir jogos de console.

Feito com Qt Quick (PySide6) renderizando direto em D3D11/D3D12 — sem navegador.

## Download

Pegue o `CaptureView.exe` na página de [Releases](../../releases). É um arquivo único, não precisa instalar.

## Recursos

- **Captura**: escolhe placa, resolução/FPS/formato (YUYV, NV12, MJPEG), áudio da placa e saída de áudio. Lembra tudo.
- **Modo GPU**: nitidez adaptativa (AMD CAS) + brilho, contraste e saturação.
- **Frame gen (30 → 60)**: detecta quadros repetidos (jogo a 30 fps dentro de sinal de 60 Hz) e gera o quadro intermediário com estimativa de movimento por block matching. Custa 1 quadro (~16 ms) de atraso. Não faz nada se o jogo já roda a 60.
- **D3D12**: opção de renderizador para usar ReShade com add-ons DX12 (veja [docs/COMO-USAR-RESHADE-DLSS5.md](docs/COMO-USAR-RESHADE-DLSS5.md)).
- **Recuperação**: se a placa parar de mandar imagem (ocupada por outro app), reabre sozinha e, se preciso, troca o formato.

Atalhos: `F` / duplo clique = tela cheia · `H` = esconder painel · `S` = FPS · `Esc` = sair da tela cheia.

## Limitações

- **Não é DLSS, FSR 3/4 nem AFMF.** Essas tecnologias precisam de dados do jogo (vetores de movimento, profundidade) ou de hardware específico (FSR 4 = AMD RX 9000). Vídeo de placa de captura só tem a imagem, então o frame gen aqui é interpolação de vídeo — bom em movimento moderado, com artefatos em movimento muito rápido (> ~40 px por quadro) e bordas de objetos.
- Para frame gen de qualidade maior, o [Lossless Scaling](https://store.steampowered.com/app/993090/Lossless_Scaling/) (LSFG) aplicado na janela do CaptureView continua sendo a melhor opção.

## Dicas

- Use porta **USB 3.0** direto na placa-mãe — em USB 2.0 a placa cai para MJPEG/1080p50.
- Melhor modo: **1920x1080 @ 60 YUYV** (sem compressão).
- No console: saída 1080p, HDR desligado, RGB Range igual ao da placa.
- No OBS: capture a **janela** do CaptureView, não a placa direto (só um app por vez pode usar a placa).

## Compilar

Precisa de Python 3.12+.

```bat
build.bat
```

Gera `dist\CaptureView.exe`. Rodar sem compilar: `.venv\Scripts\python main.py`.

Teste dos shaders de frame gen (cena sintética, não precisa da placa):

```bat
.venv\Scripts\python tests\fgtest.py
```

## Licença

MIT. Qt/PySide6 sob LGPLv3.
