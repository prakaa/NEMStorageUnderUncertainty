function _get_times_index(t::DateTime, times::Vector{DateTime})
    return findall(time -> time == t, times)[]
end

function _get_times_frequency_in_hours(times::Vector{DateTime})
    unique_diffs = unique([times[i] - times[i - 1] for i in range(2, length(times))])
    if length(unique_diffs) > 1
        throw(ArgumentError("times should have a consistent frequency"))
    else
        return Minute(unique_diffs[]).value / 60.0
    end
end
