


def hex_format(val):

    hex_str = hex(val)
    
    if(len(hex_str) == 2+4):#If it's already the correct length
        return hex_str
    elif(len(hex_str) == 2+3):#If it's missing one zero
        return hex_str[0:2] + '0' + hex_str[2:5]
    elif(len(hex_str) == 2+2):#if it's missing two zeros
        return hex_str[0:2] + "00" + hex_str[2:4]
    else:
        raise RuntimeError("Unable to format hex string")


infile = ""
outfile = ""

file_ob = open(infile, 'r')
lines = file_ob.readlines()
file_ob.close()

instr_list = [];

line_cnt = 0
for l in lines:

    pos = 0
    line_cnt += 1
    curr_inst = 0 #Current instruction to be parsed here
    
    while(pos < len(l)):
    
        #If this character is the start of a comment
        if(l[pos] == "/"):
            if(pos < len(l)-1 and l[pos+1] == "/"):
                #This is a comment so we just go to the next line
                break
            else:
                raise RuntimeError("Syntax error at line " + str(line_cnt) + ": " + l + ", expected comment but found invalid character.\n")
        #otherwise if this character is just a space        
        elif(l[pos] == " "):
            pos += 1;
            continue
        #Otherwise try to match it to an instruction
        else:
            
            #If we're out of characters to read
            if(pos+3>len(l)):
                raise RuntimeError("Syntax error at line " + str(line_cnt) + ": " + l + ", unexpected end of line\n")
        
            #Find the target instruction
            instr = l[pos:pos+3]
        
            if(instr == "MRA"):
                curr_inst |= (1<<3)
            elif(insr == "MRC"):
                curr_inst |= (1<<4)
            elif(insr == "MZA"):
                curr_inst |= (1<<5)
            elif(insr == "MZC"):
                curr_inst |= (1<<6)
            elif(insr == "RMA"):
                curr_inst |= (1<<0)
            elif(insr == "RMC"):
                curr_inst |= (1<<2)
            elif(insr == "RMB"):
                curr_inst |= (1<<1)
            elif(insr == "SWI"):
                curr_inst |= (1<<7)
            else:
                raise RuntimeError("Syntax error at line " + str(line_cnt) + ": " + l + ", invalid instruction: " + curr_inst + "\n")

            #look at the next character
            if(l[pos+3] == ","):
                #Just go to the next instruction
                pos += 4
                continue;
            elif(l[pos+3] == ";"):
                #Finish this instruction and go to the next
                pos += 4;
                instr_list += [curr_inst]
                curr_inst = 0
                continue
            else:
                raise RuntimeError("Syntax error at line " + str(line_cnt) + ": " + l + ", unexpected character: " + l[pos+3] + "\n")

#Write the instruction list to a file
file_ob = open(outfile, "w")

for inst in instr_list:
    file_ob.write(hex_format(inst))
    
file_ob.close()