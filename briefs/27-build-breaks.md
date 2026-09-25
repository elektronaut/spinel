status: claimed
branch: fix-build-breaks

# build-breaks (handles: bleak-thrasher, olive-nightjar)

Two C build errors found by workers. Both reproduce on master. Separate root
causes; one branch each.

## bleak-thrasher: a write node passed as an argument to a mutable-string parameter

`show(buf = +"abc")`, where `show`'s parameter is a STRBUF, emits
`sp_String * _t2 = _t1` with `_t1` a `const char *`. A plain `show(+"xy")` and a
non-STRBUF `show(t = "zz")` both work, so the gap is the call-argument arm's
handling of a write node. Found by the brief-14 session.

- `27-build-breaks/write_as_arg.rb`

## olive-nightjar: a yielding method reached only through a zero-argument poly call gets an untyped proc form

`w`'s parameters are never typed, because no call site passes arguments, and
`sp_A_w_pf` reads them from the boxed argument slots as `sp_int`. The fix
probably belongs in the proc-form emitter (an untyped parameter should default
to poly), not in dispatch. Found by the brief-15 session.

- `27-build-breaks/zero_arg_yield_pf.rb`
