# Dialyzer false-positive from crux: the MapSet in Crux.Formula's :auxiliaries
# field has its internal representation exposed by Crux.Formula.from_expression/1,
# tripping call_without_opaque when the result is piped into Crux.decision_tree/2.
# https://github.com/ash-project/crux/issues/32
[
  {"lib/ash_diagram/data/policy_simulation.ex", :call_without_opaque}
]
