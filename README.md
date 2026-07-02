# BA_showcase
Ein exemplarischer Aufbau für die Benutzung des Tools "testAuditor", welches ich im Rahmen meiner Bachelorarbeit entwickelt habe (siehe [repository](https://github.com/Zip-creations/optimize_CI_deterministic_builds/tree/main)).
Enthalten ist ein Demo-Pythonprojekt, welches die Implementierung einer einfachen Todo-Liste unter Zuhilfenahme von pytest abtestet.

Besonders interessant sind die 3 Projekt-spezifischen Dateien, welce die Funktionalität von testAuditor in eine Pipeline einbinden:
- [testDiscovery.sh](/src/code/testDiscovery.sh):
Liefert eine Liste aller Testcases des Projekts in einem spezifiziertem XML-Format
- [testExecution.sh](/src/code/testExecution.sh):
Liefert dem Tool eine Schnittstelle, um eine bestimmte Menge an Testcases auszuführen
- [control.sh](/src/code/control.sh):
Stellt die Funktionalität der Pipeline zur Verfügung

Der Ablauf im Detail:
1) `ta-from-discovery()` ruft [testDiscovery.sh](/src/code/testDiscovery.sh) auf, legt Ausgabe auf stdout
2) `ta-from-wrapper()` ließt alle bisherigen notes unter `git/notes/testreports` aus und baut zusammen mit dem output von `ta-from-discovery` das testAuditorInput-XML Format, das von testAuditor erwartet wird, und legt dieses auf stdout
3) `ta-from-auditor()` ruft testAuditor mit der Ausgabe von `ta-from-wrapper()` auf, legt Ausgabe auf stdout
4) `ta-from-execution()` ruft [testExecution.sh](/src/code/testExecution.sh) mit der Ausgabe von `ta-from-auditor()` auf
5) `ta-write-note()` legt die Ausgabe von `ta-from-execution()`, die vom Testframework erzeugt wird, in eine neue git note innerhalb der `git/notes/testreports` ref ab. 

[control.sh](/src/code/control.sh) stellt zwei Möglichkeiten bereit, Tests auszufüren: 
- `test-pick()` nimmt eine Liste von Testcase-Namen, die der Definition von qualifiedName folgen; d.h. direkt in dieser Form vom Testframework verstanden werden. Es werden genau die angegeben Testcases ausgeführt, unabhängig davon, ob sie innerhalb des aktuellen commits bereits ausgeführt worden sind. 
- `test-all()` führt alle Tests aus, die von testAuditor als noch nicht ausgeführt bewertet werden.
In beiden Fällen wird das Ergebnis als git note innerhalb der ref `git/notes/testreports` hinterlegt.

Über `show-notes()` können alle notes für den aktuellen Commit angezeit werden.

<!-- In dieser Demo wird ein außerhalb des Projektes liegendes lokales repository genutzt, um den hook bei einem push zu triggern. -->
