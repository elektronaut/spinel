status: claimed
branch: fix-block-forward-drops

# block-forward-drops (handles: ruddy-tern, slate-curlew)

Blocks forwarded through a method are lost. Probably two root causes; one branch each.

## ruddy-tern: a class method's `new(&h)` / `self.new(&h)` drops the block

`def self.make(&h) = new(&h)` into `initialize(&h)` fails to compile
(`too few arguments to function 'sp_Reg_new'`); `self.new(&h)` compiles but
passes no block (`undefined method 'call' for nil`). It reproduces without
inlining.

- `23-block-forward-drops/class_new_bare.rb`, `23-block-forward-drops/class_new.rb`

## slate-curlew: a named `&blk` forwarded into an anonymous `&` forwarder into a keeper is lost

Named → named and anonymous → anonymous work; the mixed shape gives
"undefined method 'call' for nil". The inline splice of a named forward into an
anonymous one doesn't resolve the nested anonymous `&` back to the outer
literal block. See `resolve_forwarded_block` / `g_block_param_name`
(codegen_fold.c) and the #4618 note in codegen_iter.c
(`desugar_value_callable_forwards`).

- `23-block-forward-drops/named_into_anon.rb`
