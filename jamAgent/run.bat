
for /l %%x in (1,1,%1) do  start "agentTask_%%x" jruby --server -J-Djruby.thread.pooling=true -Xerrno.backtrace=true createUniverse.rb %2 1> %%x.out 2> %%x.err