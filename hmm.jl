mutable struct State
    follow_tags::Dict{String, Int}
    assoc_words::Dict{String, Int}
end
State() = State(Dict{String, Int}(),
                Dict{String, Int}())


mutable struct Lexicon
    pos_dict::Dict{String, Int}
    word_dict::Dict{String, Int}
    state_dict::Dict{String, State}
    pos_count_vec::Vector{Int}
    init_pis::Vector{Float64}
end
Lexicon() = Lexicon(Dict{String, Int}(), 
                    Dict{String, Int}(),
                    Dict{String, State}(),
                    Vector{Int}(),
                    Vector{Float64}())


"""
    update_lexicon!(lex, word_tag)

Update the values in the lexicon, which inlcude the following tags, tag and
word association counts, and node/state insertions.
"""
function update_lexicon!(lex::Lexicon, word_tag::Array, tag_id::Int,
                         word_id::Int, prev_tag::String, start::Bool)
    word = word_tag[1]
    tag = word_tag[2]

    if prev_tag != ""
        if get(lex.state_dict[prev_tag].follow_tags, tag, 0) == 0
            lex.state_dict[prev_tag].follow_tags[tag] = 1
        else
            lex.state_dict[prev_tag].follow_tags[tag] += 1
        end
    end

    if get(lex.pos_dict, tag, 0) == 0
        lex.pos_dict[tag] = length(lex.pos_dict) + 1
        lex.state_dict[tag] = State()

        push!(lex.pos_count_vec, 1)
        push!(lex.init_pis, 0)
    else
        lex.pos_count_vec[lex.pos_dict[tag]] += 1
    end

    start && (lex.init_pis[lex.pos_dict[tag]] += 1)

    if get(lex.word_dict, word, 0) == 0
        lex.word_dict[word] = length(lex.word_dict) + 1
        lex.state_dict[tag].assoc_words[word] = 1
    else
        if get(lex.state_dict[tag].assoc_words, word, 0) == 0
            lex.state_dict[tag].assoc_words[word] = 1
        else
            lex.state_dict[tag].assoc_words[word] += 1
        end
    end
end


"""
    fit!(filename, vocab)

Fit the given corpora to a Vocabulary. Occurences, associations and 
follow-tags are kept track of for hidden markov model implmentation
"""
function fit!(filename::String, lex::Lexicon)
    tag_id = 1
    word_id = 1
    prev_tag = ""
    start_count = 0
    is_start = true

    #TODO remove
    break_count = 0

    open(filename) do file
        for ln in eachline(file)
            if ln == ""
                is_start = true
            else
                word_tag = split(ln, '\t')

                update_lexicon!(lex, word_tag, tag_id, word_id,
                                String(prev_tag), is_start)
                if is_start
                    start_count += 1
                    is_start = false
                end

                prev_tag = word_tag[2]
            end


            #break_count == 30 ? break : break_count += 1
        end
    end

    lex.init_pis = lex.init_pis / sum(collect(values(lex.init_pis)))
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


"""
    find_possible_tags(lex, sentence)

Vector a vector of all the unique tags associated with the given sentence
"""
function find_possible_tags(lex::Lexicon, sentence::Vector{String})
    associated_tags = Vector{String}()
    for (tag, state) in lex.state_dict
        for word in sentence
            if word in keys(state.assoc_words)
                push!(associated_tags, tag)
                break
            end
        end
    end

    return associated_tags
end


"""
    get_pi_proba(lex, tags)

Return a vector of initial probabilities for the given tags
"""
function get_pi_proba(lex::Lexicon, tags::Vector{String})
    pi_vec = Vector{Float64}()

    for t in tags
        push!(pi_vec, lex.init_pis[lex.pos_dict[t]])
    end

    return pi_vec
end


"""
    get_emission_proba(lex, tags, word)

Return a vector of observation likelihoods for the given word and its
associated with the given tags
"""
function get_emission_proba(lex::Lexicon, tags::Vector{String}, word::String)
    emission_vec = Vector{Float64}()

    for t in tags
        if get(lex.state_dict[t].assoc_words, word, 0) == 0
            push!(emission_vec, 0)
        else
            tag_count = lex.pos_count_vec[lex.pos_dict[t]]
            push!(emission_vec, lex.state_dict[t].assoc_words[word] / tag_count)
        end
    end

    return emission_vec
end


"""
    get_transition_proba(lex, tags, prev_tag)

Return a vector of transition probabilities for the most likely previous tag
and all the possible tags
"""
function get_transition_proba(lex::Lexicon, tags::Vector{String}, prev_tag::String)
    transition_vec = Vector{Float64}()

    for t in tags
        if get(lex.state_dict[prev_tag].follow_tags, t, 0) == 0
            push!(transition_vec, 0)
        else
            follow_count = lex.state_dict[prev_tag].follow_tags[t]
            prev_count = lex.pos_count_vec[lex.pos_dict[prev_tag]]
            push!(transition_vec, follow_count / prev_count)
        end
    end

    return transition_vec
end


"""
    assign_first_col!(lat, lex, first_word, tags)

Assign the first column of the lattice which the product of pi, the initial
probability distribution and the observation likelihood
"""
function assign_first_col!(lat::Array{Float64}, lex::Lexicon, first_word::String,
                          tags::Vector{String})
    pi_vec = get_pi_proba(lex, tags)
    emission_vec = get_emission_proba(lex, tags, first_word)

    lat[:, 1] = pi_vec .* emission_vec

    return lat
end


"""
    complete_lattice!(lat, lex, sentence, tags)

Fill in the remaining cells of the lattice matrix. Each cell is the product of
the Viterbi path probability, transition probability and state observation
likelihood (emission probability)
"""
function complete_lattice!(lat::Array{Float64}, lex::Lexicon,
                           sentence::Vector{String}, tags::Vector{String})
    tag_check = Vector{String}()

    for i in 2:size(lat)[2]
        prev_vit, index = findmax(lat[:, i - 1])
        prev_tag = tags[index]
        
        push!(tag_check, prev_tag)

        emission_vec = get_emission_proba(lex, tags, sentence[i])
        transition_vec = get_transition_proba(lex, tags, prev_tag)

        new_lat_col = emission_vec .* transition_vec
        lat[:, i] = new_lat_col * prev_vit
    end

    println(tag_check)
end


"""
    generate_lattice(lex, sentence)

Produce a probability matrix, lattice, for the given sentence.
"""
function generate_lattice(lex::Lexicon, sentence::Vector{String})
    possible_tags = find_possible_tags(lex, sentence) 

    lattice = zeros(length(possible_tags), length(sentence))
    assign_first_col!(lattice, lex, sentence[1], possible_tags)
    complete_lattice!(lattice, lex, sentence, possible_tags)

    return lattice
end


function main(args)
    lexicon = Lexicon()
    
    fit!("./corpora/POS_train.pos", lexicon)

    tagless_words = obtain_tagless("./corpora/POS_dev.words")
    println("Working with the following sentence:\n$(tagless_words[1])")
    lattice = generate_lattice(lexicon, tagless_words[1])

    println(lattice)
end

main(ARGS)
