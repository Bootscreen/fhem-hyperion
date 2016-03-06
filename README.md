Dies ist ein Modul für FHEM um Hyperion Server zu "steuern"

Mit dem Modul kann man die Farbe einstellen oder Effekte starten. Man kann diese auch zeitlich begrenzen.
Der Hyperion Server muss dazu den JSON Server aktiviert haben.

Define
    define <name> Hyperion <IP oder HOSTNAME> <PORT>

Set <required> [optional]

    clear löscht alle Farben und Effekte
    color <RRGGBB> [Dauer] [Priorität] sendet die Farbe in RGB Hex Format mit optionaler Dauer und Priorität
    color_g sendet die Farbe in RGB Hex Format aus dem Colorpicker
    effect <Effekt> [Dauer] [Priorität] startet den Effekt (Leerzeichen müssen durch Unterstriche ersetzt werden, siehe dazu 'get <name> effectList') mit optionaler Dauer und Priorität
    effect_g startet den Effekt aus der Dropdown Liste
    loadEffects Lädt die Effekte aus dem Attribut effects in die Dropdown Liste für effect_g
    off Schaltet das Licht aus indem es die Farbe auf schwarz setzt


Get

    effectList holt eine Liste von Effekten vom Hyperion Server und speichert diese im Attribut effects


Attributes

    effects Liste von Effekten für die Dropdown Liste effect_g
    duration Standard Dauer, wenn nicht gesetzt ist die Dauer unendlich
    priority Standard Priorität, wenn nicht gesetzt ist die Priorität 500
    verbose 4 aktiviert einige Logeinträge


Readings

    state
        success: wenn get oder set clear erfoglreich
        started infinity: wenn set effect oder color ohne Dauer gestartet
        started: wenn set effect oder color mit Dauer gestartet
        finished: wenn set effect oder color mit Dauer beendet
    last_result zeigtdie letzte Antwort von hyperion
    last_command zeigtden zuletzt gesendeten Befehl
    last_type zeigtden zuletzt gesendeten Typ
    last_value zeigtden zuletzt gesendeten Typ-Parameter
    last_duration zeigtden zuletzt gesendete Dauer
    last_priority zeigt den zuletzt gesendete Priorität
