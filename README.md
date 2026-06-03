# TaxRide 🚕

TaxRide to nowoczesna aplikacja mobilna stworzona dla kierowców pracujących na platformach takich jak **Uber**, **Bolt** oraz **FreeNow**. Aplikacja pozwala na łatwe zarządzanie finansami, ewidencjonowanie faktur kosztowych oraz automatyczne wyliczanie podatku ryczałtowego na podstawie wprowadzonych przychodów.

## Funkcje

- **Zarządzanie Przychodami**: Dodawanie przychodów z podziałem na źródła (Uber, Bolt, FreeNow) oraz typy (podstawa, bonusy).
- **Ewidencja Faktur**: Przechowywanie informacji o kosztach (paliwo, serwis, prowizje) w celu optymalizacji podatkowej.
- **Automatyczny Kalkulator Podatkowy**: Aplikacja automatycznie oblicza podatek ryczałtowy (8.5%) na podstawie zaawansowanego wzoru uwzględniającego koszty stałe i zmienne.
- **Historia Miesięczna**: Możliwość przeglądania archiwalnych danych i wyliczeń podatkowych z poprzednich miesięcy.
- **Przechowywanie Lokalne**: Dane są zapisywane w bezpiecznych plikach JSON w pamięci urządzenia (`path_provider`).
- **Polska Lokalizacja**: Pełne wsparcie dla języka polskiego, formatów dat i waluty PLN.

## Wzór Obliczeniowy

Aplikacja stosuje precyzyjny algorytm obliczania podstawy opodatkowania:

```Podstawa = (0.92 * b) - (0.15 * c) + (0.92 * d) - (0.15 * e) + (0.92 * f) - (0.15 * g) - (0.75 * h) - 184.92 Podatek = Podstawa * 8.5%```

*Gdzie: b, d, f - przychody; c, e, g - bonusy; h - suma faktur.*

## Technologia

Aplikacja została zbudowana przy użyciu:
- **Flutter & Dart** - framework do tworzenia aplikacji mobilnych.
- **Intl** - lokalizacja i formatowanie dat (pl_PL).
- **Path Provider** - obsługa systemu plików urządzenia.
- **Material 3** - nowoczesny interfejs użytkownika zgodny z najnowszymi trendami.

## Instalacja i Uruchomienie

1. Upewnij się, że masz zainstalowany [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Sklonuj repozytorium:
   ```bash
   git clone https://github.com/paweljjar/TaxRide.git
   ```
3. Przejdź do folderu projektu:
   ```bash
   cd TaxRide
   ```
4. Pobierz zależności:
   ```bash
   flutter pub get
   ```
5. Uruchom aplikację:
   ```bash
   flutter run
   ```
