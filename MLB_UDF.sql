CREATE OR REPLACE FUNCTION TBRDP_DW_PROD.IM_RPT.GET_MLB_GAME_RESULT(GAMEPK NUMBER)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('requests')
EXTERNAL_ACCESS_INTEGRATIONS = (MLB_STATS_API_ACCESS)
HANDLER = 'get_game_result'
COMMENT = 'Fetches game result from MLB Stats API for a given GAMEPK'
AS 'import requests

def get_game_result(gamepk):
    try:
        url = f"https://statsapi.mlb.com/api/v1.1/game/{int(gamepk)}/feed/live"
        resp = requests.get(url, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        game_data = data.get("gameData", {})
        live_data = data.get("liveData", {})
        status = game_data.get("status", {}).get("abstractGameState", "Unknown")
        home_team = game_data.get("teams", {}).get("home", {}).get("abbreviation", "")
        away_team = game_data.get("teams", {}).get("away", {}).get("abbreviation", "")
        game_date = game_data.get("datetime", {}).get("officialDate", "")
        linescore = live_data.get("linescore", {}).get("teams", {})
        home_score = linescore.get("home", {}).get("runs")
        away_score = linescore.get("away", {}).get("runs")
        rays_home = home_team == "TB"
        if home_score is not None and away_score is not None:
            if rays_home:
                rays_win = home_score > away_score
                opponent = away_team
            else:
                rays_win = away_score > home_score
                opponent = home_team
        else:
            rays_win = None
            opponent = away_team if rays_home else home_team
        return {"gamePk": int(gamepk), "gameDate": game_date, "status": status, "homeTeam": home_team, "awayTeam": away_team, "homeScore": home_score, "awayScore": away_score, "raysHome": rays_home, "raysWin": rays_win, "opponent": opponent}
    except Exception as e:
        return {"gamePk": int(gamepk), "error": str(e)}';
