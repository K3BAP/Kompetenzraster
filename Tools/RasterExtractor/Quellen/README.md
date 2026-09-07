# Quellen der Kompetenzraster

Die drei Teilrahmenpläne liegen bewusst **nicht** im Repository: Es sind rund 11 MB
Ministeriums-PDFs, die sich jederzeit frei nachladen lassen. Für `swift run RasterExtractor`
werden sie hier unter genau diesen Namen erwartet.

Alle drei stammen vom [Bildungsserver Rheinland-Pfalz](https://bildung.rlp.de/grundschule/fortbildung-und-beratung):

| Datei | Herkunft |
|---|---|
| `TRP_Deutsch.pdf` | Teilrahmenplan Deutsch |
| `TRP_Mathematik.pdf` | Teilrahmenplan Mathematik |
| `TRP_Sachunterricht.pdf` | Teilrahmenplan Sachunterricht |

```bash
BASIS=https://bildung.rlp.de/fileadmin/user_upload/grundschule.bildung.rlp.de/Rechtsgrundlagen/Rahmenplaene
curl -Lo TRP_Deutsch.pdf        "$BASIS/TRP_Deutsch_f._Bildungsserver.pdf"
curl -Lo TRP_Mathematik.pdf     "$BASIS/Rahmenplan_Grundschule_TRP_Mathe_01_08_2015.pdf"
curl -Lo TRP_Sachunterricht.pdf "$BASIS/TRP_Sachunterricht_f._Bildungsserver__2_.pdf"
```

Deutsch und Mathematik enthalten auslesbaren Text. Der Teilrahmenplan Sachunterricht ist ein
Scan und wird vom Werkzeug per Vision-Texterkennung gelesen; dessen Ergebnis braucht eine
redaktionelle Durchsicht, bevor es in `Kompetenzraster/Resources/Vorlagen/` landet.
