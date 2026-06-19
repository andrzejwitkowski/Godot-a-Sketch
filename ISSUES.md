# Godot-a-Sketch - Lista Zgłoszeń (Issues)

## 1. Inicjalizacja Pluginu
**Etykiety:** `enhancement`, `technical`, `priority:high`

**Opis:**
Konfiguracja podstawowej struktury pluginu Godot.

**Zadania:**
- Utworzenie pliku `plugin.cfg` z metadanymi pluginu (nazwa, opis, wersja, autor)
- Implementacja głównej klasy pluginu dziedziczącej po `EditorPlugin`
- Dodanie metod `_enter_tree()` i `_exit_tree()` do zarządzania cyklem życia pluginu
- Rejestracja pluginu w systemie edytora Godot
- Konfiguracja autoload (jeśli wymagane)
- Dodanie podstawowej obsługi sygnałów edytora

**Kryteria akceptacji:**
- Plugin pojawia się w liście pluginów Godot
- Plugin może być włączony/wyłączony bez błędów
- Podstawowa klasa pluginu ładuje się poprawnie

---

## 2. Panel UI (Dock)
**Etykiety:** `enhancement`, `ui`, `priority:high`

**Opis:**
Stworzenie interfejsu użytkownika w formie docka w edytorze Godot.

**Zadania:**
- Utworzenie kontrolki `Control` dla panelu docka
- Dodanie listy shaderów (Stack) z możliwością dodawania/usuwania
- Implementacja sekcji ustawień pędzla:
  - Size (rozmiar) - slider lub spinbox
  - Opacity (przezroczystość) - slider 0-100%
  - Hardness (twardość) - slider 0-100%
- Podpięcie panelu do `EditorPlugin` jako dock
- Zapisywanie stanu panelu między sesjami edytora

**Kryteria akceptacji:**
- Dock widoczny w edytorze po włączeniu pluginu
- Lista shaderów funkjonalna (dodawanie/usuwanie)
- Suwaki pędzla aktualizują parametry w czasie rzeczywistym

---

## 3. System Raycast
**Etykiety:** `technical`, `enhancement`, `priority:high`

**Opis:**
Implementacja systemu wykrywania obiektów pod kursorem w widoku 3D.

**Zadania:**
- Nadpisanie metody `_forward_3d_gui_input()` w `EditorPlugin`
- Implementacja logiki wysyłania promieni (ray) z kamery edytora
- Wykrywanie trafień za pomocą `PhysicsDirectSpaceState3D.intersect_ray()`
- Konwersja pozycji myszy na współrzędne ekranowe
- Obsługa różnych stanów inputu (klik, przytrzymanie, ruch)
- Filtrowanie obiektów do raycastu (tylko obiekty z odpowiednią warstwą)

**Kryteria akceptacji:**
- Raycast trafiał w obiekty 3D w scenie
- Pozycja trafienia jest dokładna
- System działa płynnie bez opóźnień

---

## 4. Wskaźnik Pędzla (Ghost Brush)
**Etykiety:** `enhancement`, `ui`, `priority:medium`

**Opis:**
Wizualizacja kursora pędzla w widoku 3D pokazująca zasięg i pozycję.

**Zadania:**
- Utworzenie wizualnego wskaźnika (MeshInstance3D lub ImmediateMesh)
- Implementacja podążania wskaźnika za kursorem (na podstawie raycastu)
- Dynamiczna zmiana rozmiaru wskaźnika zgodnie z ustawieniami pędzla
- Opcjonalnie: zmiana koloru w zależności od trybu (malowanie/rzeźbienie)
- Renderowanie wskaźnika tylko w widoku 3D edytora
- Obsługa przezroczystości wskaźnika

**Kryteria akceptacji:**
- Wskaźnik widoczny w widoku 3D
- Podąża za myszką w czasie rzeczywistym
- Rozmiar odpowiada ustawieniom pędzla

---

## 5. System Stackowania Shaderów (Resource)
**Etykiety:** `technical`, `enhancement`, `priority:high`

**Opis:**
Stworzenie systemu zasobów do przechowywania informacji o shaderach na obiektach.

**Zadania:**
- Utworzenie klasy `ShaderStack` dziedziczącej po `Resource`
- Dodanie eksportowanej listy shaderów z parametrami
- Implementacja struktury danych dla każdego shadera:
  - Referencja do shadera
  - Parametry (waga, tryb blendowania)
  - Kolejność nakładania
- Zapisywanie `ShaderStack` jako zasób `.tres`
- Możliwość przypisania `ShaderStack` do obiektu 3D
- Obsługa duplikowania i kopiowania stacków

**Kryteria akceptacji:**
- Zasób `ShaderStack` tworzy się poprawnie
- Można dodać wiele shaderów do stacku
- Stack zapisuje się i ładuje bez utraty danych

---

## 6. Splat Map Engine
**Etykiety:** `technical`, `enhancement`, `priority:high`

**Opis:**
Implementacja systemu renderowania operacji pędzla na teksturze maski (Splat Map).

**Zadania:**
- Utworzenie `SubViewport` do renderowania off-screen
- Konfiguracja viewportu:
  - Rozmiar zgodny z teksturą maski
  - Format tekstury (RGBA8 lub odpowiedni)
  - Tryb renderowania bez wyświetlania
- Implementacja logiki nakładania kształtu pędzla na teksturę
- Obsługa wielu warstw (kanały RGBA dla różnych shaderów)
- Aktualizacja tekstury w czasie rzeczywistym podczas malowania
- Optymalizacja renderowania (tylko podczas aktywnej operacji)

**Kryteria akceptacji:**
- SubViewport renderuje operacje pędzla
- Tekstura maski aktualizuje się płynnie
- Wynikowa tekstura może być użyta jako maska

---

## 7. Obsługa Malowania
**Etykiety:** `technical`, `enhancement`, `priority:high`

**Opis:**
Implementacja logiki nanoszenia kształtu pędzla na teksturę maski.

**Zadania:**
- Utworzenie shadera do renderowania kształtu pędzla
- Implementacja różnych kształtów pędzla (okrąg, kwadrat, tekstura)
- Obsługa parametrów pędzla:
  - Rozmiar (size)
  - Przezroczystość (opacity)
  - Twardość krawędzi (hardness)
- Nakładanie kształtu na teksturę maski w pozycji kursora
- Obsługa trybów blendowania (add, subtract, multiply)
- Interpolacja między pozycjami kursora (dla płynnych linii)
- Obsługa nacisku tabletu (opcjonalnie)

**Kryteria akceptacji:**
- Pędzel maluje na teksturze maski
- Parametry pędzla wpływają na wynik
- Malowanie jest płynne przy szybkim ruchu myszką

---

## 8. Integracja z Materiałami
**Etykiety:** `technical`, `enhancement`, `priority:high`

**Opis:**
Automatyczne generowanie i konfigurowanie materiałów dla meshów.

**Zadania:**
- Implementacja automatycznego tworzenia `ShaderMaterial` na meshu
- Generowanie shadera terenu z obsługą wielu warstw
- Podpinanie tekstury maski (Splat Map) pod uniformy shadera
- Konfiguracja uniformów dla każdej warstwy shadera:
  - Tekstury albedo/normal/diffuse
  - Parametry skalowania UV
  - Wagi mieszania
- Aktualizacja materiału po zmianie stacku shaderów
- Obsługa wielu meshów z tym samym materiałem

**Kryteria akceptacji:**
- Materiał generuje się automatycznie po dodaniu shaderów
- Tekstura maski kontroluje widoczność warstw
- Zmiana maski aktualizuje wygląd meshu

---

## 9. Moduł Sculpting (Heightmap)
**Etykiety:** `enhancement`, `priority:medium`

**Opis:**
Dodanie trybu rzeźbienia terenu poprzez edycję heightmapy.

**Zadania:**
- Implementacja trybu rzeźbienia (przełączanie z trybu malowania)
- Edycja heightmapy zamiast tekstury maski
- Obsługa operacji:
  - Podnoszenie terenu (raise)
  - Obniżanie terenu (lower)
  - Wygładzanie (smooth)
  - Spłaszczanie (flatten)
- Wizualizacja heightmapy w edytorze
- Ograniczenia zakresu wysokości (min/max)
- Obsługa różnych kształtów pędzla dla rzeźbienia

**Kryteria akceptacji:**
- Można przełączać między trybem malowania a rzeźbienia
- Rzeźbienie modyfikuje geometrię terenu
- Operacje są intuicyjne i kontrolowane

---

## 10. Dynamic Subdivision
**Etykiety:** `technical`, `enhancement`, `priority:medium`

**Opis:**
Implementacja algorytmu dynamicznego zagęszczania siatki dla obiektów do rzeźbienia.

**Zadania:**
- Implementacja algorytmu subdividowania meshu
- Podział trójkątów w obszarach wymagających szczegółów
- Adaptacyjne zagęszczanie na podstawie:
  - Rozmiaru pędzla
  - Aktualnej rozdzielczości siatki
  - Krzywizny powierzchni
- Optymalizacja: subdividowanie tylko w obszarze operacji
- Zachowanie normalnych i UV po subdividowaniu
- Opcjonalnie: upraszczanie siatki (decimation) po zakończeniu

**Kryteria akceptacji:**
- Siatka zagęszcza się w obszarze rzeźbienia
- Jakość siatki pozostaje wysoka
- Wydajność jest akceptowalna

---

## 11. Aktualizacja Fizyki
**Etykiety:** `technical`, `priority:medium`

**Opis:**
Automatyczne przeliczanie kolizji po operacjach rzeźbienia.

**Zadania:**
- Wykrywanie zmian w geometrii meshu
- Automatyczne przebudowywanie `ConcavePolygonShape3D` lub `HeightMapShape3D`
- Aktualizacja `CollisionShape3D` w `StaticBody3D`
- Optymalizacja: opóźniona aktualizacja po zakończeniu operacji
- Obsługa wielu obiektów z kolizjami
- Sygnalizowanie postępu przebudowy (dla dużych meshów)

**Kryteria akceptacji:**
- Kolizje aktualizują się po rzeźbieniu
- Fizyka działa poprawnie po zmianach
- Brak zauważalnych opóźnień

---

## 12. Undo/Redo System
**Etykiety:** `enhancement`, `priority:high`

**Opis:**
Integracja z systemem cofania akcji edytora Godot.

**Zadania:**
- Użycie `EditorUndoRedoManager` do zarządzania akcjami
- Implementacja akcji dla operacji malowania:
  - Zapisywanie stanu przed/po
  - Przywracanie tekstur maski
- Implementacja akcji dla operacji rzeźbienia:
  - Zapisywanie stanu geometrii
  - Przywracanie meshu
- Grupowanie operacji (cały ruch pędzla jako jedna akcja)
- Optymalizacja pamięci (kompresja stanów)
- Obsługa wielu obiektów w jednej akcji

**Kryteria akceptacji:**
- Ctrl+Z cofa ostatnią operację
- Ctrl+Y przywraca cofniętą operację
- System działa dla malowania i rzeźbienia

---

## 13. Zapisywanie Danych
**Etykiety:** `technical`, `priority:high`

**Opis:**
Implementacja zapisu tekstur maski i innych danych do plików projektu.

**Zadania:**
- Zapisywanie tekstur maski jako pliki `.png` lub `.tres`
- Organizacja plików w folderze projektu:
  - Struktura katalogów
  - Nazewnictwo plików
- Zapisywanie konfiguracji shaderów
- Zapisywanie ustawień pluginu
- Obsługa ścieżek względnych do zasobów
- Automatyczne tworzenie folderów jeśli nie istnieją
- Walidacja ścieżek przed zapisem

**Kryteria akceptacji:**
- Tekstury zapisują się do plików
- Pliki są widoczne w systemie plików projektu
- Dane ładują się poprawnie po restarcie edytora

---

## 14. Optymalizacja Wydajności
**Etykiety:** `technical`, `priority:medium`

**Opis:**
Ograniczenie operacji zapisu na dysk do momentu zwolnienia przycisku myszy.

**Zadania:**
- Buforowanie operacji w pamięci podczas malowania/rzeźbienia
- Zapis na dysk tylko przy zdarzeniu `mouse_up`
- Implementacja bufora dla tekstur maski
- Optymalizacja renderowania SubViewport:
  - Renderowanie tylko podczas aktywnej operacji
  - Pauzowanie gdy brak zmian
- Ograniczenie aktualizacji kolizji (batch update)
- Monitorowanie wydajności (fps, użycie pamięci)
- Opcjonalnie: asynchroniczny zapis w tle

**Kryteria akceptacji:**
- Brak zauważalnych spadków wydajności podczas malowania
- Zapis na dysk następuje tylko po zwolnieniu przycisku
- Pamięć jest zwalniana po zapisie

---

## Podsumowanie Etykiet

| Etykieta | Opis | Kolor |
|----------|------|-------|
| `enhancement` | Nowa funkcjonalność lub ulepszenie | #a2eeef |
| `technical` | Wymagania techniczne, implementacja | #0075ca |
| `ui` | Interfejs użytkownika | #e99695 |
| `priority:high` | Wysoki priorytet | #d93f0b |
| `priority:medium` | Średni priorytet | #fbca04 |
| `priority:low` | Niski priorytet | #0e8a16 |

## Kolejność Implementacji (Sugerowana)

1. **Faza 1 - Podstawy:**
   - #1 Inicjalizacja Pluginu
   - #2 Panel UI (Dock)
   - #3 System Raycast

2. **Faza 2 - Malowanie:**
   - #4 Wskaźnik Pędzla (Ghost Brush)
   - #5 System Stackowania Shaderów (Resource)
   - #6 Splat Map Engine
   - #7 Obsługa Malowania
   - #8 Integracja z Materiałami

3. **Faza 3 - Rzeźbienie:**
   - #9 Moduł Sculpting (Heightmap)
   - #10 Dynamic Subdivision
   - #11 Aktualizacja Fizyki

4. **Faza 4 - Udostępnianie:**
   - #12 Undo/Redo System
   - #13 Zapisywanie Danych
   - #14 Optymalizacja Wydajności
