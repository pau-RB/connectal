
set_false_path -from [get_clocks clkgen_pll_CLKOUT1] -to   [get_clocks userclk2]
set_false_path -to   [get_clocks clkgen_pll_CLKOUT1] -from [get_clocks userclk2]

set_false_path -from [get_clocks clkgen_pll_CLKOUT1] -to   [get_clocks clkgen_pll_CLKOUT1]
set_false_path -to   [get_clocks clkgen_pll_CLKOUT1] -from [get_clocks clkgen_pll_CLKOUT1]
