Projekt: Dockabase

🔧 Opis ogólny
Dockabase to open-source'owy projekt, którego celem jest umożliwienie błyskawicznego uruchomienia bazy wektorowej Qdrant w środowisku kontenerowym Docker, wraz z gotowym docker-compose.yml, prostym tutorialem i zestawem przydatnych komend.

Tutaj budujemy landing page reklamujacyistniejace repo z qdrant + caddy postawione na dockerze. Te repo istnieje, tutaj budujemy tylko landing page.

Projekt udostępnia minimalistyczny, ale estetyczny landing page zbudowany w Astro, który pełni funkcję dokumentacji oraz strony startowej projektu.

🧱 Stack technologiczny
Frontend / Landing Page:
Astro v4.6.3 (najnowsza wersja na dzień 2025-05-24)

Framework do statycznych stron, idealny do dokumentacji i landing page’y

Tailwind CSS v3.4.1

Utility-first CSS framework, używany do stylowania

Markdown (MDX) + @astrojs/mdx

Do zarządzania treścią tutoriali, README i dokumentacji

System kontenerowy:
Docker
Docker Compose

Strone odpalamy w dockerze
Nginx jako server web
inne rzeczy tez w dockerze

Musimy przygotowac konfig kontenerow do uruchomienia lokalnie jak i na serverze digitalocean.


Serwer i hosting:
VPS (DigitalOcean) z systemem Ubuntu

Serwer dedykowany do hostowania statycznej strony oraz ewentualnej przyszłej infrastruktury

Deployment & CI/CD:
GitHub Actions

Automatyzacja buildów i deploymentu

Workflow zdefiniowany w .github/workflows/deploy.yml

Mechanizm deployu:

Trigger: Merge pull requesta do gałęzi master

Build Astro → przesłanie zawartości katalogu dist na VPS (np. przez scp/rsync)

Bezpieczeństwo:
Sekrety GitHub Actions (VPS_HOST, VPS_USER, VPS_SSH_KEY) używane do połączenia SSH

Prywatne klucze przechowywane wyłącznie w zaszyfrowanych secretach GitHub

📦 Struktura katalogów (planowana)
/src – komponenty i strony Astro

/public – statyczne zasoby (favicon, logo, screeny)

/docs – tutoriale w Markdownie

/scripts – ewentualne helpery do lokalnego startu/deployu

.github/workflows/ – konfiguracja GitHub Actions

📋 Główne funkcje strony:
Hasło i skrócony opis projektu

Sekcja z najważniejszymi komendami do użycia (z przyciskiem "copy")

Link do GitHub repo

Tutorial krok po kroku (w formacie Markdown)

Możliwość przetestowania (np. link do demo lub instrukcja lokalnego odpalenia)

🛠️ Potencjalne rozszerzenia (MVP+1):
Try-it-now live playground (np. demo z Qdrant REST API)

Sekcja z najczęstszymi problemami (FAQ)

Wyszukiwarka po komendach / errorach

Webhook do automatycznego restartowania kontenera na VPS po deployu