"""Register only this app's context-menu entries for the current user."""
from pathlib import Path
import sys
import winreg

ROOT = Path(__file__).resolve().parent
EXTENSIONS = ('mp3', 'wav', 'm4a', 'flac', 'ogg', 'opus', 'aac', 'wma', 'aiff', 'aif', 'mp4', 'mkv', 'webm', 'm4b', 'amr', 'mpga')
BASE = r'Software\Classes\SystemFileAssociations'
KEY = 'KBLocalTranscriber'


def install():
    command = f'powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "{ROOT / "Transkribera.ps1"}" -AudioPath "%1"'
    for ext in EXTENSIONS:
        path = BASE + '\\.' + ext + '\\shell\\' + KEY
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path) as key:
            winreg.SetValueEx(key, '', 0, winreg.REG_SZ, 'Transkribera ljudfil')
            winreg.SetValueEx(key, 'Icon', 0, winreg.REG_SZ, 'shell32.dll,168')
            winreg.SetValueEx(key, 'MultiSelectModel', 0, winreg.REG_SZ, 'Single')
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, path + '\\command') as key:
            winreg.SetValueEx(key, '', 0, winreg.REG_SZ, command)
    for ext in EXTENSIONS:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, BASE + '\\.' + ext + '\\shell\\' + KEY + '\\command') as key:
            assert winreg.QueryValueEx(key, '')[0] == command
    print('Högerklicksmenyn har installerats och verifierats för', len(EXTENSIONS), 'filtyper.')


def uninstall():
    for ext in EXTENSIONS:
        path = BASE + '\\.' + ext + '\\shell\\' + KEY
        for suffix in ('\\command', ''):
            try:
                winreg.DeleteKey(winreg.HKEY_CURRENT_USER, path + suffix)
            except FileNotFoundError:
                pass
    print('Programmets högerklicksmeny har tagits bort.')


if __name__ == '__main__':
    uninstall() if '--uninstall' in sys.argv else install()
