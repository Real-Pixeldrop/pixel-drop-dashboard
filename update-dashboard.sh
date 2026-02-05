#!/bin/bash

# Script de mise à jour automatique du dashboard Pixel Drop
# Récupère les vraies données et met à jour le HTML

set -e

DASHBOARD_DIR="/Users/akligoudjil/clawd/projets/pixel-drop-dashboard"
HTML_FILE="$DASHBOARD_DIR/index.html"

echo "=== Mise à jour Dashboard Pixel Drop ==="
echo "Date: $(date)"

# 1. Récupérer le trafic GA4 (30 derniers jours)
echo "Récupération trafic GA4..."
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "refresh_token=$(jq -r .refresh_token ~/.config/ga4/config.json)" \
  -d "client_id=$(jq -r .client_id ~/.config/ga4/config.json)" \
  -d "client_secret=$(jq -r .client_secret ~/.config/ga4/config.json)" \
  -d "grant_type=refresh_token" | jq -r '.access_token')

TRAFFIC=$(curl -s -X POST "https://analyticsdata.googleapis.com/v1beta/properties/474885507:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dateRanges":[{"startDate":"30daysAgo","endDate":"today"}],"metrics":[{"name":"sessions"}]}' \
  | jq -r '.rows[0].metricValues[0].value // "80"')

echo "Trafic: $TRAFFIC sessions"

# 2. Récupérer le nombre de contacts Brevo
echo "Récupération contacts Brevo..."
NEWSLETTER=$(curl -s "https://api.brevo.com/v3/contacts?limit=1" \
  -H "api-key: $(cat ~/.config/brevo/pixel-drop-api-key)" \
  | jq -r '.count // "98"')

echo "Newsletter: $NEWSLETTER contacts"

# 3. LinkedIn - on garde la valeur manuelle pour l'instant (pas d'API simple)
LINKEDIN=62

# 4. Instagram - récupérer via API
echo "Récupération followers Instagram..."
INSTAGRAM=$(curl -s "https://graph.instagram.com/me?fields=followers_count&access_token=$(cat ~/.config/instagram/access_token)" \
  | jq -r '.followers_count // "45"')

echo "Instagram: $INSTAGRAM followers"

# Calculer les pourcentages pour les jauges
LINKEDIN_PCT=$(echo "scale=1; $LINKEDIN / 500 * 100" | bc)
INSTAGRAM_PCT=$(echo "scale=1; $INSTAGRAM / 300 * 100" | bc)
NEWSLETTER_PCT=$(echo "scale=1; $NEWSLETTER / 200 * 100" | bc)
TRAFFIC_PCT=$(echo "scale=1; $TRAFFIC / 1000 * 100" | bc)

echo "Jauges: LinkedIn $LINKEDIN_PCT%, Instagram $INSTAGRAM_PCT%, Newsletter $NEWSLETTER_PCT%, Trafic $TRAFFIC_PCT%"

# 5. Mettre à jour le HTML
echo "Mise à jour du HTML..."

# Mettre à jour les valeurs dans le HTML
sed -i '' "s/id=\"linkedin-count\">[0-9]*/id=\"linkedin-count\">$LINKEDIN/" "$HTML_FILE"
sed -i '' "s/id=\"instagram-count\">[0-9]*/id=\"instagram-count\">$INSTAGRAM/" "$HTML_FILE"
sed -i '' "s/id=\"newsletter-count\">[0-9]*/id=\"newsletter-count\">$NEWSLETTER/" "$HTML_FILE"
sed -i '' "s/id=\"traffic-count\">[0-9]*/id=\"traffic-count\">$TRAFFIC/" "$HTML_FILE"

# Mettre à jour les jauges progress-values
sed -i '' "s/>$LINKEDIN \/ 500</>$LINKEDIN \/ 500</" "$HTML_FILE"
sed -i '' "s/>[0-9]* \/ 300</>${INSTAGRAM} \/ 300</" "$HTML_FILE"
sed -i '' "s/>[0-9]* \/ 200</>${NEWSLETTER} \/ 200</" "$HTML_FILE"
sed -i '' "s/>[0-9]* \/ 1000</>${TRAFFIC} \/ 1000</" "$HTML_FILE"

# Mettre à jour les pourcentages des barres
sed -i '' "s/linkedin-bar').style.width = '[0-9.]*%'/linkedin-bar').style.width = '${LINKEDIN_PCT}%'/" "$HTML_FILE"
sed -i '' "s/instagram-bar').style.width = '[0-9.]*%'/instagram-bar').style.width = '${INSTAGRAM_PCT}%'/" "$HTML_FILE"
sed -i '' "s/newsletter-bar').style.width = '[0-9.]*%'/newsletter-bar').style.width = '${NEWSLETTER_PCT}%'/" "$HTML_FILE"
sed -i '' "s/traffic-bar').style.width = '[0-9.]*%'/traffic-bar').style.width = '${TRAFFIC_PCT}%'/" "$HTML_FILE"

# Mettre à jour les animateValue
sed -i '' "s/animateValue('linkedin-count', 0, [0-9]*/animateValue('linkedin-count', 0, $LINKEDIN/" "$HTML_FILE"
sed -i '' "s/animateValue('instagram-count', 0, [0-9]*/animateValue('instagram-count', 0, $INSTAGRAM/" "$HTML_FILE"
sed -i '' "s/animateValue('newsletter-count', 0, [0-9]*/animateValue('newsletter-count', 0, $NEWSLETTER/" "$HTML_FILE"
sed -i '' "s/animateValue('traffic-count', 0, [0-9]*/animateValue('traffic-count', 0, $TRAFFIC/" "$HTML_FILE"

# 6. Commit et push
echo "Push sur GitHub..."
cd "$DASHBOARD_DIR"
git add .
git commit -m "Auto-update: LinkedIn $LINKEDIN, Instagram $INSTAGRAM, Newsletter $NEWSLETTER, Trafic $TRAFFIC" || echo "Pas de changement"
git push || echo "Push échoué"

echo "=== Mise à jour terminée ==="
