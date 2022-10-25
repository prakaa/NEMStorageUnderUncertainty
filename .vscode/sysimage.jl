using JuMP, HiGHS, Gurobi, Cbc

for optimizer in (HiGHS.Optimizer, Gurobi.Optimizer, Cbc.Optimizer)
    model = Model(optimizer)
    @variable(model, x >= 0)
    @variable(model, 0 <= y <= 3)
    @objective(model, Min, 12x + 20y)
    @constraint(model, c1, 6x + 8y >= 100)
    @constraint(model, c2, 7x + 12y >= 120)
    optimize!(model)
end

using Plots
p = plot(rand(2,2))
display(p)
