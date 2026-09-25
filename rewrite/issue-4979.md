Under an empty or C locale (for example `LANG=` or a bare `env -i`), `tools/rubyspec/extract.rb` reads the ruby/spec files as US-ASCII and crashes at the first line containing a non-ASCII character, so every spec file after it in the glob is never extracted. `make gate-rubyspec` doesn't notice: it goes on to run the partial extraction and still prints `rubyspec-gate[language]: all N expected-PASS examples still pass`. Under that locale the `language` suite extracted only 498 of its 2399 examples.

A spec dir with one file containing `"é"` (`a_spec.rb`) and one plain-ASCII file (`b_spec.rb`), extracted from the repo root with an empty environment:

```sh
mkdir -p spec
cat > spec/a_spec.rb <<'RUBY'
describe "String#size" do
  it "counts characters" do
    "é".size.should == 1
  end
end
RUBY
cat > spec/b_spec.rb <<'RUBY'
describe "Integer#+" do
  it "adds" do
    (1 + 2).should == 3
  end
end
RUBY
env -i PATH=$PATH ruby tools/rubyspec/extract.rb spec out
```

Both examples should be extracted (under `LANG=C.UTF-8` it prints `extracted 2 examples into out`), and if extraction does fail the gate should fail with it. Instead the extractor exits 1 with `` tools/rubyspec/extract.rb:66:in `strip': invalid byte sequence in US-ASCII (Encoding::CompatibilityError) `` and writes nothing, not even `b_spec__001.rb`. Inside `make gate-rubyspec`, the gate still reports every suite as passing.

`extract.rb` reads the specs with `File.readlines` under the locale's default external encoding, so `String#strip` raises on the first UTF-8 line and aborts the whole `Dir.glob` loop. The `rubyspec-gate` recipe in the `Makefile` ignores the exit status of both `extract.rb` and `run.sh` (which exits 2 on a listed example missing from the extraction), and counts regressions with `awk ... | wc -l` over a results file that was never written, which gives 0.
