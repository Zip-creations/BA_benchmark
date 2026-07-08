# BA_benchmark
Dies ist ein experimenteller Aufbau, der die Laufzeiten von dem Verfahren, welches ich im Rahmen meiner Bachelorarbeit entwickelt habe (siehe [repository](https://github.com/Zip-creations/optimize_CI_deterministic_builds/tree/main)), erfasst und mit den Laufzeiten eines vollständigen Testdurchlaufs vergleicht.

Dazu werden verschiedene benches durchlaufen, welche alle dem selben Aufbau folgen:<br>
bench_* enthält folgende Komponenten:
- `archive`: 
Ein Ordner, der je nach bench entweder leer ist, oder die Datei `out.xml` beinhaltet. `out.xml` simuliert eine Menge von bereits ausgeführten Testcases.
- `test_simple*.py`:
Eine nicht leere Menge von Testdateien, welche die zu Menge von Testcases im Projekt darstellt
- `result`:
Ein Ordner, der die resultierende .log Datei(n) aus einem Durchlauf der bench enthält.

Die Benchmark kann auf zweierlei Weise ausgeführt werden:

- `benchmark.sh` lässt jede bench genau einmal laufen
- `benchmark_repeat.sh` lässt jede bench 10 mal laufen, und legt jedes Ergebnis mitsamt der zusätzlichen Datei `average.log` in `result` ab
