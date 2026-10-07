[
  tools: [
    # Sobelow's Vuln checks only match six 2017-18 CVEs (hex.audit covers
    # dependency advisories properly), and they parse mix.lock in a way
    # Elixir 1.20 warns about once per locked dependency.
    {:sobelow, "mix sobelow --exit --ignore Vuln"}
  ]
]
