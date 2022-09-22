# -*- coding: UTF-8 -*-
import os
import re

DocumentName = ""
DocumentContent = ""
fo = None

# 先清理一遍目录下之前的文件
def ClearFile(dir_path):
    dir_list = []
    g = os.walk(dir_path)
    for root,dirs,files in g:
        dir_list.append(root)
    for name in files:
        os.remove(os.path.join(root, name))


# 读取源文件<所念皆星辰>
def ReadFile(file_path):
    global DocumentName
    global DocumentContent
    global fo
    OUTPUT_DIRECTORY = "../output/"
    f = open(file_path, "rb")
    line = f.readline()
    while line:
        if line.startswith("![]("):
            line = line.replace("![](", "![](../")
        print(line)
        ret = re.match("^[#]*", line).group(0)
        if ret:
            match_len = len(ret)
            if match_len == 1: # 表明是一个新的文件
                # 筛选掉 #include类似的代码文件
                if line[match_len:].startswith(" ") and not line[match_len:].strip("\n").strip("\r").endswith("#"):
                    DocumentName = OUTPUT_DIRECTORY + line[match_len:].strip("\n").strip(" ").strip("\r") + ".md"
                    if DocumentName != "":
                        fo = open(DocumentName.decode('utf-8').encode('gb2312'), "wb")
                else:
                    if fo:
                        fo.write(line)
            else:
                if fo:
                    fo.write(line)
        else:
            if fo:
                fo.write(line)

        line = f.readline()

    f.close()
    fo.close()

if __name__ == '__main__':
    print("====================开始生成文件========================")
    ClearFile(r"..\output\\")
    ReadFile("..\Rime.md")