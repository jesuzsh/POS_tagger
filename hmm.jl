mutable struct State
    # TODO
    follow_tag::Dict{String, Int}
    assoc_words::Dict{String, Int}
end
State() = State(Dict{String, Int}(),
                Dict{String, Int}())


mutable struct Lattice
    pos_dict::Dict{String, Int}
    word_dict::Dict{String, Int}
    state_dict::Dict{String, State}
    pos_count_vec::Vector{Int}

    # TODO
    init_pis::Dict{String, Float64}
end
Lattice() = Lattice(Dict{String, Int}(), 
                    Dict{String, Int}(),
                    Dict{String, State}(),
                    Vector{Int}(),
                    Dict{String, Float64}())


"""
    update_lattice!(lattice, word_tag)

Update the values in the lattice, which inlcude the following tags, tag and
word association counts, and node/state insertions.
"""
function update_lattice!(lat::Lattice, word_tag::Array, tag_id::Int,
                         word_id::Int, prev_tag::String)
    word = word_tag[1]
    tag = word_tag[2]

    # TODO follow/next tag
    if prev_tag != ""
        if get(lat.state_dict[prev_tag].follow_tag, tag, 0) == 0
            lat.state_dict[prev_tag].follow_tag[tag] = 1
        else
            lat.state_dict[prev_tag].follow_tag[tag] += 1
        end
    end


    if get(lat.pos_dict, tag, 0) == 0
        lat.pos_dict[tag] = length(lat.pos_dict) + 1
        push!(lat.pos_count_vec, 1)
        #lat.pos_count_dict[tag] = 1
        lat.state_dict[tag] = State()
    else
        lat.pos_count_vec[lat.pos_dict[tag]] += 1
    end

    if get(lat.word_dict, word, 0) == 0
        lat.word_dict[word] = length(lat.word_dict) + 1
        lat.state_dict[tag].assoc_words[word] = 1
    else
        if get(lat.state_dict[tag].assoc_words, word, 0) == 0
            lat.state_dict[tag].assoc_words[word] = 1
        else
            lat.state_dict[tag].assoc_words[word] += 1
        end
    end


end


"""
    fit!(filename, vocab)

Fit the given corpora to a Vocabulary. Occurences, associations and 
follow-tags are kept track of for hidden markov model implmentation
"""
function fit!(filename::String, lat::Lattice)
    tag_id = 1
    word_id = 1
    prev_tag = ""
    start = true

    break_count = 0

    open(filename) do file
        for ln in eachline(file)
#            println(ln)
            if ln == ""
                start = true
            else
                word_tag = split(ln, '\t')

                update_lattice!(lat, word_tag, tag_id, word_id, String(prev_tag))
#                println(lat)
                prev_tag = word_tag[2]
            end

            break_count += 1

#            if break_count == 15
#                break
#            end
        end
    end
end


function main(args)
    lattice = Lattice()
    
    fit!("./corpora/POS_train.pos", lattice)

    #println(lattice.state_dict)
    println(lattice.pos_count_vec)

end


main(ARGS)
