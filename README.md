### Required software and packages

- Julia >= 1.0.5

### Running the program

`julia hmm.jl <training_file> <test_file> <output_file>`

Each line of the training file is a word followed by its part-of-speech tag.
Tab separated. Sentences are separated by an empty line.

The test file should be formatted like the training file. The only difference
is that the part-of-speech tag is missing.

Output file will be created by running the program and be the labeled version
of test file.
