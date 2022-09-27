# -*- coding: UTF-8 -*-
"""
@author: zhangsuohao
@contact: zhangshnju@gmail.com
@file: GenerateDocuments.py
@time: 2022/9/22 19:34
@desc: 将《所念皆星辰.md》文件，按照标题内容拆分，生成至output目录下，拆分为对应标题以及内容的独立文本
@Intepreter: Python2.7.exe
 """
import os
import re

DocumentName = ""
DocumentContent = ""
OUTPUT_DIRECTORY = "../output/"
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
    global OUTPUT_DIRECTORY
    f = open(file_path, "rb")
    line = f.readline()
    while line:
        # 因为文件在output目录下，资源文件在output目录的上层，所以在索引资源的时候做一次..层级替换
        if line.startswith("![](res"):
            line = line.replace("![](res", "![](../res")
        if "](res" in line:
            line = line.replace("](res", "](../res")
        # 将代码部分的中文\r\n做\n处理，避免一行换行被处理成两行空格，不美观
        if "\r\n" in line:
            line = line.replace("\r\n", "\n")
        print(line)
        ret = re.match("^[#]*", line).group(0)
        if ret:
            match_len = len(ret)
            if match_len == 1: # 表明是一个新的文件
                # 筛选掉 #include类似的代码文件
                if line[match_len:].startswith(" ") and not line[match_len:].strip("\n").strip("\r").endswith("#"):
                    DocumentName = OUTPUT_DIRECTORY + line[match_len:].strip("\n").strip(" ").strip("\r") + ".md"
                    if DocumentName != "":
                        fo = open(DocumentName.decode('utf-8').encode('gb2312'), "a")
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
    ReadFile("..\所念皆星辰.md".decode('utf-8').encode('gb2312'))