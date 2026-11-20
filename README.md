# KB Transkriberare

Ett Windows-program som transkriberar svenska och engelska ljudfiler lokalt på datorn. Programmet använder **KB-Whisper** för svenska och **Distil-Whisper** för engelska och sparar resultatet som en Markdown-fil i samma mapp som ljudfilen.

```text
intervju.mp3 → intervju.md
```

## Funktioner

- Starta från ett programfönster eller via ljudfilens högerklicksmeny.
- Välj svenska eller engelska.
- Välj mellan KB-Whisper Small för snabbare bearbetning och Large för högre noggrannhet.
- Följ transkriberingen med förloppsindikator, hastighet, förfluten tid och uppskattad återstående tid.
- Spara löpande text med styckeindelning, utan tidsangivelser.
- Öppna transkriptionen eller dess mapp direkt när arbetet är klart.
- Avbryt transkriberingen utan att spara en ofullständig Markdown-fil.
- Få en fråga innan en befintlig transkription ersätts.

## Lokal behandling

Ljudfilerna lämnar aldrig datorn. När programbibliotek och modeller har laddats ner kan transkriberingen köras utan internetanslutning. Programmet använder processorn med INT8-beräkningar och kräver inget NVIDIA-grafikkort.

## Installation

Kräver 64-bitars Windows med Windows PowerShell 5.1 och internetanslutning under installationen. Reservera minst 8 GB ledigt diskutrymme. Modellvikterna tar cirka 5,1 GB tillsammans. Programmet har testats på en dator med 32 GB RAM; detta är inte ett fastställt minimikrav.

1. Hämta repot med **Code → Download ZIP** och packa upp det i en lokal mapp, eller klona det:

   ```sh
   git clone https://github.com/kredor/KbWhisperTrans.git
   ```

2. Dubbelklicka på **Installera.cmd**. Installationen hämtar en separat Python 3.12.10-miljö, programbibliotek och samtliga tre modeller. Behåll filerna i samma mapp. Vid avbruten nedladdning kan installationen köras igen; färdiga modellfiler kontrolleras och återanvänds.
3. Starta programmet genom att dubbelklicka på **Starta.vbs**.
4. För högerklicksfunktionen: kör **Installera-hogerklick.cmd** en gång. Registreringen gäller ditt användarkonto och kräver normalt inte administratörsrättigheter.

I Windows 11 kan **Transkribera ljudfil** ligga under **Visa fler alternativ**. Om programmappen flyttas behöver högerklicksinstallationen köras igen. **Ta-bort-hogerklick.cmd** tar bort programmets egna menyval utan att radera ljud eller transkriptioner.

Om VBScript inte är tillgängligt kan programmet startas från PowerShell i programmappen:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Transkribera.ps1
```

Modellfiler och Python-miljö ingår inte i Git-repot; de hämtas av installationsprogrammet. Ingen separat FFmpeg-installation behövs.

## Teknik

- **Python** för transkriberingsmotorn.
- **PowerShell och Windows Forms** för användargränssnittet.
- **Faster-Whisper och CTranslate2** för modellkörning.
- **PyAV** för inläsning av ljud.
- **KB-Whisper Small och Large** för svenska.
- **Distil-Whisper Large v3** för engelska.

Programmet har en separat Python-miljö. Högerklicksmenyn installeras för det aktuella Windows-kontot. Exakta biblioteksversioner finns i `requirements-lock.txt`. Modellernas revisioner är låsta i `download_models.py`, som verifierar modellvikternas SHA-256 mot publicerade metadata.

## Användning

1. Starta programmet och välj en ljudfil.
2. Välj språk och, för svenska, modellstorlek.
3. Klicka på **Starta transkribering**.
4. Följ förloppet i programfönstret.
5. Den färdiga texten sparas bredvid ljudfilen med samma namn och filändelsen `.md`.

Vanliga ljudformat som MP3, WAV, M4A och FLAC stöds. Programmet kan även läsa ljudspår från kompatibla videofiler. Texten sparas som UTF-8. Talet transkriberas på det valda språket och översätts inte.

## Felsökning

- **Nätverksmappen går inte att öppna:** filväljaren börjar i programmets lokala mapp. För ljud på en nätverksenhet krävs åtkomst till enheten, eller en lokal kopia av filen.
- **Transkriptionen går inte att spara:** kontrollera att du har skrivrättighet i ljudfilens mapp.
- **Öppna transkription fungerar inte:** öppna `.md`-filen med exempelvis Anteckningar eller Obsidian.
- **Tekniskt fel:** se felmeddelandet i programfönstret och, om den finns, `senaste-felet.log` i programmappen.

## Bakgrund

Projektet inspirerades av [KBLabs artikel om easytranscriber](https://kb-labb.github.io/posts/2026-02-26-easytranscriber/). Det använder KB:s språkmodeller genom Faster-Whisper. Den fullständiga easytranscriber-pipelinen för exakt ordtidsättning ingår inte, eftersom programmet är utformat för att skapa lättlästa transkriptioner utan tidsangivelser.

## Begränsningar

Automatisk transkribering kan innehålla fel, särskilt vid bakgrundsljud, överlappande tal och ovanliga namn. Viktiga uppgifter bör kontrolleras mot originalinspelningen. Bearbetningstiden varierar med modell, ljudfil och datorns prestanda. Förlopps- och tidsuppskattningar uppdateras per textsegment och kan hoppa vid tystnad.

## Modeller och externa projekt

- [KB-Whisper Small](https://huggingface.co/KBLab/kb-whisper-small) och [KB-Whisper Large](https://huggingface.co/KBLab/kb-whisper-large).
- [Distil-Whisper Large v3 för Faster-Whisper](https://huggingface.co/Systran/faster-distil-whisper-large-v3).
- [Faster-Whisper](https://github.com/SYSTRAN/faster-whisper).

Externa bibliotek och modeller omfattas av sina respektive licenser. Modellkort hämtas tillsammans med modellerna.
