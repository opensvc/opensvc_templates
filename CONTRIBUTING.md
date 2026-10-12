# Contributing

Users copy the urls of these templates into their configurations and
scripts, and fetch them again when they deploy. A template file published at
a url keeps working there for the agents it requires.

* A change to a published file is a fix: it keeps working with the agents the
  template requires.
* A change needing a newer agent, or breaking how the template is deployed, is
  a new generation: copy the newest generation into a new directory of the
  template, `v2/`, `v3/`..., and change the copy.
* The README of a generation says the minimal agent it requires, at its top.
  The README of the template lists its generations, the newest first, with the
  agent each requires.
* The files of a generation name only the files of that generation in their
  urls.
* No alias names "the latest" generation: a link that moves breaks whoever
  copied it, which is what the generations are for.
