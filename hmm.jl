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
    pos_count_vec::Vector{Int}
    init_pis::Vector{Float64}
end
Lattice() = Lattice(Dict{String, Int}(), 
                    Dict{String, Int}(),
                    Dict{String, State}(),
                    Vector{Int}(),
                    Vector{Float64}())


"""
    update_lattice!(lattice, word_tag)

Update the values in the lattice, which inlcude the following tags, tag and
word association counts, and node/state insertions.
"""
function update_lattice!(lat::Lattice, word_tag::Array, tag_id::Int,
                         word_id::Int, prev_tag::String, start::Bool)
    word = word_tag[1]
    tag = word_tag[2]

    if prev_tag != ""
        if get(lat.state_dict[prev_tag].follow_tag, tag, 0) == 0
            lat.state_dict[prev_tag].follow_tag[tag] = 1
        else
            lat.state_dict[prev_tag].follow_tag[tag] += 1
        end
    end

    if get(lat.pos_dict, tag, 0) == 0
        lat.pos_dict[tag] = length(lat.pos_dict) + 1
        lat.state_dict[tag] = State()

        push!(lat.pos_count_vec, 1)
        push!(lat.init_pis, 0)
    else
        lat.pos_count_vec[lat.pos_dict[tag]] += 1
    end

    start && (lat.init_pis[lat.pos_dict[tag]] += 1)

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
    start_count = 0
    is_start = true

    break_count = 0

    open(filename) do file
        for ln in eachline(file)
            if ln == ""
                is_start = true
            else
                word_tag = split(ln, '\t')

                update_lattice!(lat, word_tag, tag_id, word_id,
                                String(prev_tag), is_start)
                if is_start
                    start_count += 1
                    is_start = false
                end

                prev_tag = word_tag[2]
            end

            break_count += 1

            """
            if break_count == 30
                break
            end
            """
        end
    end

    lat.init_pis = lat.init_pis / sum(collect(values(lat.init_pis)))
end


"""
    obtain_tagless(filename)

Parse the given file of words and obtain sentences that are meant to have tags
assigned using hidden markov models and viterbi decoding
"""
function obtain_tagless(filename::String)
    corpora_vec = Vector{Vector{String}}()
    sentence_vec = Vector{String}()

    #TODO remove
    break_count = 0

    open(filename) do file
        for ln in eachline(file)
            if ln == ""
                push!(corpora_vec, sentence_vec)
                sentence_vec = Vector{String}()
            else
                push!(sentence_vec, ln)
            end 

            #break_count == 100 ? break : break_count += 1
        end
    end
    
    return corpora_vec
end


function main(args)
    lattice = Lattice()
    
    fit!("./corpora/POS_train.pos", lattice)

    tagless_words = obtain_tagless("./corpora/POS_dev.words")
    println(tagless_words[1])
end

main(ARGS)
