# Dockabase - Product Requirements Document (PRD)

## 1. Wprowadzenie i cel projektu

Dockabase to open-source'owy projekt, którego głównym celem jest umożliwienie deweloperom i użytkownikom szybkiego uruchomienia bazy wektorowej Qdrant w środowisku kontenerowym Docker. Projekt dostarcza gotową konfigurację docker-compose.yml, prosty tutorial oraz zestaw przydatnych komend, które znacząco upraszczają proces wdrożenia i korzystania z bazy wektorowej.

Głównym elementem projektu jest minimalistyczny, ale estetyczny landing page zbudowany w technologii Astro, który pełni funkcję dokumentacji oraz strony startowej projektu. Strona ta będzie zawierać wszystkie niezbędne informacje i zasoby potrzebne do szybkiego rozpoczęcia pracy z Qdrant w kontenerze Docker.

### Grupa docelowa
- Deweloperzy i użytkownicy, którzy chcą szybko uruchomić bazę wektorową i z niej korzystać
- Osoby poszukujące prostego rozwiązania do wdrożenia Qdrant w środowisku kontenerowym

### Problemy rozwiązywane przez Dockabase
- Uproszczenie procesu uruchamiania bazy wektorowej Qdrant w kontenerze Docker
- Dostarczenie gotowej konfiguracji, która działa "out of the box"
- Zapewnienie jasnej dokumentacji i tutoriali dla użytkowników

## 2. Zakres projektu

### Co zawiera MVP
- Landing page z opisem projektu i podstawowymi informacjami
- Podstrony:
  - FAQ
  - Tutorial Qdrant API
  - Troubleshooting
  - Deployment
  - Domain and SSL
- Link do repozytorium GitHub
- Responsywny design (dostosowany do różnych urządzeń)
- Instrukcje wdrożenia na serwerze VPS wraz z konfiguracją SSL (Let's Encrypt)

### Co nie jest częścią MVP
- Live playground / demo
- Wyszukiwarka po komendach/errorach
- Wielojęzyczność (tylko wersja angielska)
- Webhook do automatycznego restartowania kontenera na VPS po deployu

## 3. Kluczowe funkcjonalności

### Landing Page
- Hasło i skrócony opis projektu
- Sekcja z najważniejszymi komendami do użycia (z przyciskiem "copy")
- Link do repozytorium GitHub
- Nawigacja do podstron

### Podstrony
1. **FAQ** - najczęściej zadawane pytania i odpowiedzi
2. **Tutorial Qdrant API** - instrukcje korzystania z API Qdrant
3. **Troubleshooting** - rozwiązywanie typowych problemów
4. **Deployment** - szczegółowe instrukcje wdrożenia
5. **Domain and SSL** - konfiguracja domeny i certyfikatu SSL

### Funkcjonalności techniczne
- Responsywny design (mobile-first)
- Dark theme (czerń, odcienie czerni, jasna zieleń)
- Nowoczesna typografia (techniczna czcionka)
- Optymalizacja pod kątem SEO

## 4. Technologia i stack

### Frontend / Landing Page
- **Astro v4.6.3** - framework do statycznych stron, idealny do dokumentacji i landing page'y
- **Tailwind CSS v3.4.1** - utility-first CSS framework do stylowania
- **Markdown (MDX) + @astrojs/mdx** - do zarządzania treścią tutoriali i dokumentacji

### System kontenerowy
- **Docker** - do konteneryzacji aplikacji
- **Docker Compose** - do orkiestracji kontenerów
- **Nginx** - jako serwer web

### Serwer i hosting
- **VPS (DigitalOcean)** z systemem Ubuntu
- **Let's Encrypt** - do generowania certyfikatów SSL

### Deployment & CI/CD
- **GitHub Actions** - automatyzacja buildów i deploymentu
- Workflow zdefiniowany w `.github/workflows/deploy.yml`
- Trigger: Merge pull requesta do gałęzi master
- Build Astro → przesłanie zawartości katalogu dist na VPS (np. przez scp/rsync)

### Bezpieczeństwo
- Sekrety GitHub Actions (VPS_HOST, VPS_USER, VPS_SSH_KEY) używane do połączenia SSH
- Prywatne klucze przechowywane wyłącznie w zaszyfrowanych secretach GitHub

## 5. Struktura repozytorium / plików

```
/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── src/
│   ├── components/
│   │   ├── Header.astro
│   │   ├── Footer.astro
│   │   ├── CommandCopy.astro
│   │   └── ...
│   ├── layouts/
│   │   ├── MainLayout.astro
│   │   └── DocLayout.astro
│   ├── pages/
│   │   ├── index.astro
│   │   ├── faq.astro
│   │   ├── tutorial-qdrant-api.astro
│   │   ├── troubleshooting.astro
│   │   ├── deployment.astro
│   │   └── domain-and-ssl.astro
│   └── styles/
│       └── global.css
├── public/
│   ├── favicon.svg
│   ├── robots.txt
│   └── assets/
│       └── images/
├── content/
│   └── docs/
│       ├── faq.md
│       ├── tutorial-qdrant-api.md
│       ├── troubleshooting.md
│       ├── deployment.md
│       └── domain-and-ssl.md
├── scripts/
│   └── deploy.sh
├── docker/
│   ├── docker-compose.yml
│   └── nginx/
│       └── default.conf
├── astro.config.mjs
├── tailwind.config.js
├── tsconfig.json
├── package.json
└── README.md
```

## 6. Proces deploymentu

### Lokalny development
1. Klonowanie repozytorium
2. Instalacja zależności: `npm install`
3. Uruchomienie lokalnego serwera: `npm run dev`
4. Build: `npm run build`

### Deployment na serwer VPS
1. Przygotowanie serwera VPS (DigitalOcean z Ubuntu)
2. Instalacja Docker i Docker Compose na serwerze
3. Konfiguracja Nginx jako reverse proxy
4. Konfiguracja Let's Encrypt dla SSL
5. Automatyczny deployment przez GitHub Actions:
   - Trigger: merge do gałęzi master
   - Build projektu Astro
   - Transfer plików na serwer przez SSH
   - Restart kontenerów (jeśli potrzebne)

### Workflow GitHub Actions
```yaml
name: Deploy to VPS

on:
  push:
    branches: [ master ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      - name: Install dependencies
        run: npm ci
      - name: Build
        run: npm run build
      - name: Deploy to VPS
        uses: appleboy/scp-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          source: "dist/"
          target: "/var/www/dockabase.com"
      - name: Restart services
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /path/to/docker-compose
            docker-compose restart nginx
```

## 7. Wymagania UX/UI

### Design
- Dark theme (czerń, odcienie czerni, jasna zieleń)
- Minimalistyczny, ale elegancki design
- Nowoczesna typografia z techniczną czcionką
- Przejrzysty układ strony z naciskiem na czytelność

### Responsywność
- Pełna responsywność na wszystkich urządzeniach (mobile, tablet, desktop)
- Mobile-first approach
- Dostosowanie układu strony do różnych rozdzielczości

### Interakcje
- Przyciski "copy" dla komend i snippetów kodu
- Płynne przejścia między podstronami
- Czytelne wyróżnienie aktywnych elementów nawigacji

## 8. Sposób wersjonowania kodu

### Repozytorium
- GitHub jako platforma hostingowa dla kodu
- Proste branching (bez skomplikowanego git flow)

### Branching Strategy
- `master` - główna gałąź produkcyjna
- Feature branches dla nowych funkcjonalności
- Pull Requesty do przeglądu kodu przed mergem do master

### Wersjonowanie
- Brak formalnego semantic versioning (projekt eksperymentalny)
- Tagging ważniejszych wersji dla łatwiejszej nawigacji

## 9. Plan wdrożenia

Projekt jest rozwijany jako eksperymentalny, bez ścisłych terminów. Ogólny plan wdrożenia:

1. **Faza 1: Przygotowanie środowiska**
   - Konfiguracja repozytorium GitHub
   - Setup projektu Astro
   - Konfiguracja Tailwind CSS

2. **Faza 2: Rozwój landing page**
   - Implementacja strony głównej
   - Stworzenie podstawowych komponentów
   - Implementacja dark theme

3. **Faza 3: Rozwój podstron**
   - Implementacja wszystkich podstron (FAQ, Tutorial, Troubleshooting, Deployment, Domain and SSL)
   - Dodanie treści (placeholdery na początek)

4. **Faza 4: Deployment**
   - Konfiguracja serwera VPS
   - Setup Docker i Nginx
   - Konfiguracja SSL z Let's Encrypt
   - Implementacja CI/CD z GitHub Actions

5. **Faza 5: Testowanie i optymalizacja**
   - Testy responsywności
   - Optymalizacja wydajności
   - Finalizacja treści

## 10. Potencjalne ryzyka i pomysły na rozszerzenia

### Ryzyka
- Zmiany w API Qdrant mogące wpłynąć na aktualność tutoriali
- Zmiany w ekosystemie Docker mogące wymagać aktualizacji konfiguracji
- Potencjalne problemy z kompatybilnością różnych wersji zależności

### Pomysły na przyszłe rozszerzenia (poza MVP)
Żadne z poniższych nie jest planowane w obecnej wersji, ale mogą być rozważone w przyszłości:
- Try-it-now live playground (np. demo z Qdrant REST API)
- Sekcja z najczęstszymi problemami (rozszerzony FAQ)
- Wyszukiwarka po komendach / errorach
- Webhook do automatycznego restartowania kontenera na VPS po deployu
