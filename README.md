# BA_showcase
Ein exemplarischer Aufbau für die Benutzung des Tools, welches ich im Rahmen meiner Bachelorarbeit entwickelt habe (siehe [repository](https://github.com/Zip-creations/optimize_CI_deterministic_builds/tree/main)).
Enthalten ist ein Demo-Pythonprojekt, welches die Implementierung einer einfachen Todo-Liste unter Zuhilfenahme von pytest abtestet.

Besonders interessant sind die 4 Framework-spezifischen Dateien, die das Tool in einem Projekt erwartet:
- [testDiscovery.sh](/src/code/testDiscovery.sh):
Liefert dem Tool eine Liste aller Testcases des Projekts in einem spezifiziertem XML-Format
- [testExecution.sh](/src/code/testExecution.sh)
Liefert dem Tool eine Schnittstelle, um eine bestimmte Menge an Testcases auszuführen
- [config.json](src/code/config.json)
Liefert dem Tool die Pfade für testDiscovery.sh und testExecution.sh
- [post-receive](/src/server/hooks/post-receive)
Bindet das Tool in den Ablauf der Pipeline ein.
In dieser Demo wird ein außerhalb des Projektes liegendes lokales repository genutzt, um den hook bei einem push zu triggern.
