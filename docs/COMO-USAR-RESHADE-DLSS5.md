# CaptureView + ReShade + DLSS 5

## 1. Mudar o CaptureView para D3D12

1. Abra o `CaptureView.exe`.
2. No painel, em **Renderizador**, escolha **D3D12 (ReShade / DLSS5)**.
3. Clique em **Reiniciar para aplicar D3D12**.
4. Confira o canto superior direito: deve aparecer `D3D12`.
5. Feche o CaptureView.

## 2. Instalar o ReShade no CaptureView

1. Baixe o ReShade em <https://reshade.me>. Pegue a versão **"with full add-on support"**, porque a versão normal não carrega add-ons.
2. Execute o instalador e selecione o arquivo `CaptureView.exe` (o desta pasta).
3. Na API, escolha **Direct3D 10/11/12**.
4. Escolha os efeitos que quiser ou pule essa etapa.
5. O ReShade coloca um `dxgi.dll` e um `ReShade.ini` ao lado do `CaptureView.exe`. Mantenha tudo na mesma pasta. Se mover o .exe, mova esses arquivos junto.

## 3. Colocar o add-on do DLSS 5

O add-on não vem com o CaptureView. É um projeto da comunidade (RenoDX / DLSS5-Feeder) que usa DLLs da NVIDIA vazadas.

1. Obtenha o add-on e as DLLs pela fonte que você confia.
2. Siga as instruções do próprio add-on. Em geral, o `.addon64` e as DLLs vão **na mesma pasta do `CaptureView.exe`**.
3. Antes de usar, passe o antivírus nesses arquivos. Arquivos vazados distribuídos por Discord são um meio comum de espalhar malware.

## 4. Usar

1. Abra o CaptureView. A janela do ReShade abre com a tecla **Home**.
2. Ative o DLSS 5 na aba **Add-ons**.
3. Aperte **H** para esconder o painel do CaptureView. Os efeitos do ReShade também processam o painel e o contador de FPS.

## Avisos

- **RTX 2060:** pelos relatos, o DLSS 5 roda a cerca de 1 fps em placas RTX 30 ou mais antigas, mesmo sem nenhum jogo usando a GPU. Isso acontece por falta de recursos dos tensor cores dessas placas, e não por excesso de carga. Teste antes da live.
- **Vídeo da placa de captura:** o add-on foi feito para jogos, que fornecem profundidade e vetores de movimento. O vídeo da placa só tem a imagem, então o resultado pode ser fraco ou não funcionar.
- **Se ficar lento ou travar:** desative o add-on no ReShade (tecla Home) ou apague o `dxgi.dll` da pasta para remover o ReShade de vez. Voltar para D3D11 não basta, porque o ReShade também se injeta em D3D11.
- **Frame generation:** o Lossless Scaling (LSFG) aplicado na janela do CaptureView continua sendo a opção que funciona na RTX 2060.
