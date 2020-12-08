#### Futo-Spec

is a new BDD framework inspired by Cucumber, but greatly simplified. No Gherkin, just bullet points like this:

```
futo spec test case
- open a new .futo file
- add bullet points with a dash
- run futo command
--> should auto-detect new commands and output 'TODO'

when futo is matched to commands
- commands from futo files are matched to futo/_glue/chizu
- syntax is similar to cucumber step definitions
- run futo on a bullet point which matches a chizu
--> the associated commands in the chizu run
```

More details in [this article](https://seanfelipe.github.io/automation/test-engine/frameworks/cucumber/2020/05/30/futo-spec.html).

Happy testing !
