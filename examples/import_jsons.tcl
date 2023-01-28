# An example script that can be passed to aRTist as a startup parameter.
# It shows how to add jobs to the batch manager and start running them.

if { [::Modules::Available "CTSimU"] } {
	set ctsimu [dict get [::Modules::Get "CTSimU"] Namespace]
	if { ![winfo exists .ctsimu] } { ${ctsimu}::Run }

	# Vorsichtshalber mal die Batchliste leeren,
	# falls da zufällig etwas drin ist:
	${ctsimu}::clearBatchList

	# Beispiel 1:
	# Eine Batchjob-Liste aus einer CSV-Datei importieren:
	${ctsimu}::importBatchJobs "Z:/SimpleScan/batch.csv"

	# Beispiel 2:
	# Selbst per Hand einen Batchjob in die Liste einfügen.
	# Nur den JSON-Filenamen, der Rest wird durch Standardparameter ergänzt.
	${ctsimu}::insertBatchJob "Z:/SimpleScan/simple_scan.json"

	# Beispiel 3:
	# Nur die wichtigsten Parameter angeben, Ausgabeordner und Dateinamen werden anhand der JSON-Datei automatisch gesetzt.
	# Reihenfolge: Dateiname, Runs, Startrun, Startprojektion, Format
	${ctsimu}::insertBatchJob "Z:/SimpleScan/simple_scan.json" 10 1 0 "TIFF float32"

	# Beispiel 3:
	# Alle Parameter angeben.
	# Reihenfolge: Dateiname, Runs, Startrun, Startprojektion, Format, Ausgabeordner, Dateiname für die Projektionsbilder (base name)
	${ctsimu}::insertBatchJob "Z:/SimpleScan/simple_scan.json" 5 1 0 "RAW uint16" "Z:/SimpleScan/Projektionsbilder" "Beispielname"

	# Batchjobs starten:
	${ctsimu}::runBatch

	# Warten, bis das Modul alle Jobs abgearbeitet hat:
	while { ![${ctsimu}::CanClose] } { update; after 100 }

	# Sicherheitshalber die Batchliste noch einmal speichern.
	# Dadurch kann man später nachschauen, ob ein Run abgebrochen wurde oder Fehler aufgetaucht sind,
	# z.B. indem man die CSV-Datei mal in Excel importiert.
	${ctsimu}::saveBatchJobs "Z:/SimpleScan/final_batch_status.csv"
}

# aRTist schließen, wenn alles fertig ist:
::aRTist::shutdown -force
exit