

class Lexicon:

    def __init__(self, filename):
        f = open(filename, 'r')
        f_lines = f.readlines()

        tags = []

        for num, line in enumerate(f_lines):
            if line == '\n':
                pass
            else:
                word, pos_tag = line.split()
                tags.append(pos_tag)

        print(list(set(tags)))
