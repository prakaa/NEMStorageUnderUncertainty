using JuMP, HiGHS

model = Model(HiGHS.Optimizer)
@variable(model, x >= 0)
@variable(model, 0 <= y <= 3)
@objective(model, Min, 12x + 20y)
@constraint(model, c1, 6x + 8y >= 100)
@constraint(model, c2, 7x + 12y >= 120)
optimize!(model)

using Plots
p = plot(rand(2, 2))
display(p)

using CairoMakie
barplot([1,2,3])
lines([1,2,3])
