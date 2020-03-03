mutable struct State
    follow_tag::Dict{String, Int}
    assoc_words::Dict{String, Int}
end
State() = State(Dict{String, Int}(),
                Dict{String, Int}())


mutable struct Lattice
    pos_dict::Dict{String, Int}
    word_dict::Dict{String, Int}
    state_dict::Dict{String, State}
    pos_count_dict::Dict{String, Int}
    init_pis::Dict{String, Float64}
end
Lattice() = Lattice(Dict{String, Int}(), 
                    Dict{String, Int}(),
                    Dict{String, State}(),
                    Dict{String, Int}(),
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
        tag_id += 1
        lat.pos_dict[tag] = tag_id
        lat.pos_count_dict[tag] = 1
        lat.state_dict[tag] = State()

    else
        lat.pos_count_dict[tag] += 1
    end

    if get(lat.word_dict, word, 0) == 0
        word_id += 1
        lat.word_dict[word] = word_id
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
    tag_id = 0
    word_id = 0
    prev_tag = ""
    start = true

    break_count = 0

    open(filename) do file
        for ln in eachline(file)
            if ln == ""
                start = true
            else
                word_tag = split(ln, '\t')

                update_lattice!(lat, word_tag, tag_id, word_id, prev_tag)
                prev_tag = word_tag[2]
            end

            break_count += 1

            if break_count == 15
                break
            end
        end
    end
end


function main(args)
    lattice = Lattice()
    
    fit!("./corpora/POS_train.pos", lattice)

    println(lattice.state_dict)

end


main(ARGS)
