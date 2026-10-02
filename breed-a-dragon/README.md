# Breed a Dragon

משחק Roblox: מגדלים ומכליאים דרקונים, וכל דרקון יחיד בעולם. התוכנית המלאה נמצאת ב-[PLAN.md](PLAN.md).

## מבנה הקוד

| תיקייה | לאן היא נכנסת ב-Studio | מה יש בה |
|---|---|---|
| `src/server` | `ServerScriptService.Server` | קוד שרת: שמירה, מטבע, קריסטלים |
| `src/client` | `StarterPlayerScripts.Client` | קוד שחקן: ממשק (HUD) |
| `src/shared` | `ReplicatedStorage.Shared` | משותף: הגדרות (`Config`), תקשורת, עיצוב מספרים |

כל המספרים של איזון המשחק (מחירים, פרסים, זמנים) נמצאים ב-`src/shared/Config.luau`.

## חיבור הקוד ל-Roblox Studio (פעם אחת)

1. **התקנת VS Code**: מורידים מ-https://code.visualstudio.com ומתקינים.
2. **הורדת הפרויקט**: ב-VS Code לוחצים **Clone Git Repository**, מתחברים ל-GitHub, בוחרים את `server-project` ושומרים בתיקייה במחשב.
3. **מעבר לענף הנכון**: למטה משמאל לוחצים על שם הענף (`master`) ובוחרים `origin/claude/roblox-game-monetization-u8uu9g`.
4. **התקנת התוסף Rojo**: בלשונית Extensions (Ctrl+Shift+X) מחפשים **Rojo - Roblox Studio Sync** ומתקינים.
5. **פתיחת תיקיית המשחק**: **File** ואז **Open Folder**, ובוחרים את התיקייה `breed-a-dragon`.
6. **התקנת Rojo**: Ctrl+Shift+P, כותבים `Rojo: Open menu`. בתפריט מאשרים **Install Rojo** וגם **Install Roblox Studio plugin**.
7. **הפעלה**: באותו תפריט לוחצים על `default.project.json` כדי להפעיל את השרת.
8. **חיבור מ-Studio**: פותחים את המשחק ב-Studio, נכנסים ללשונית **Plugins**, לוחצים **Rojo** ואז **Connect**.

## עבודה שוטפת

1. ב-VS Code: Ctrl+Shift+P ואז `Git: Pull`, כדי לקבל את הקוד החדש.
2. מוודאים ש-Rojo מחובר, והקוד מתעדכן ב-Studio אוטומטית.
3. לוחצים **Play** ובודקים.

## בדיקת שלב 1

1. **Play**: אמורים להופיע 6 קריסטלים כתומים סביב נקודת ההתחלה, ומונה 🔥 בראש המסך.
2. **לחיצה על קריסטל**: המונה עולה ומופיע "+1".
3. **Stop ואז שוב Play**: ה-Embers נשמרו.
4. אם מופיעה ההודעה *Saving is off in Studio*, צריך להפעיל ב-**Game Settings** את **Security** ואז **Enable Studio Access to API Services**.
