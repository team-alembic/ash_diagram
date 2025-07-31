[
  import_deps: [:ash],
  plugins: [Styler, DoctestFormatter],
  inputs: ["{mix,.formatter,.credo}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
