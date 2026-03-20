CREATE OR REPLACE FUNCTION TBRDP_DW_PROD.IM_RPT.GET_RAYS_SCHEDULE(START_DATE VARCHAR, END_DATE VARCHAR)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('requests')
EXTERNAL_ACCESS_INTEGRATIONS = (MLB_STATS_API_ACCESS)
HANDLER = 'get_schedule'
AS 'import requests

def get_schedule(start_date, end_date):
    try:
        url = f"https://statsapi.mlb.com/api/v1/schedule?sportId=1&teamId=139&startDate={start_date}&endDate={end_date}&gameType=R"
        resp = requests.get(url, timeout=30)
        resp.raise_for_status()
        data = resp.json()
        games = []
        for date_entry in data.get("dates", []):
            for game in date_entry.get("games", []):
                games.append({"gamePk": game.get("gamePk"), "gameDate": game.get("officialDate"), "homeTeam": game.get("teams", {}).get("home", {}).get("team", {}).get("abbreviation"), "awayTeam": game.get("teams", {}).get("away", {}).get("team", {}).get("abbreviation")})
        return games
    except Exception as e:
        return {"error": str(e)}';
