# Kick off the CTSimU module. This script is
# passed to aRTist when the batch manager restarts
# after a run was finished.
if { [::Modules::Available "CTSimU"] } {
	set ctsimu [dict get [::Modules::Get "CTSimU"] Namespace]
	if { ![winfo exists .ctsimu] } { ${ctsimu}::Run }
	${ctsimu}::kickOff
}