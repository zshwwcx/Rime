# encoding: utf-8
"""
@author: zhangsuohao
@contact: zhangshnju@gmail.com
@file: FileMirage.py
@time: 2022/9/27 10:52
@desc: Conda Python3.1

通过git commit id信息获取git commit所有文件的列表，将文件直接拷贝到同结构的目标目录下。
 """
import os.path
import shutil
from git import Repo

SRC_DIR = "F:/AClient/trunk/AClient/Content" # 拷贝源根目录
DST_DIR = "G:/APGAME/AClient/trunk/AClient/Content" # 拷贝目标根目录
COMMIT_ID = "5b594554cef8635515c0b179222ab60506342a19"

if __name__ == "__main__":
    print("开始执行。\n")
    # 根据directory获取当前仓库的repo_info
    repo = Repo(SRC_DIR)
    # 通过sha检索到对应的commit info
    commit = repo.commit(COMMIT_ID)
    FILE_LIST = []
    # 遍历commint_info里面涉及的所有files
    for file_path in commit.stats.files.keys():
        print(file_path)
        src = SRC_DIR + "/" + file_path
        dst = DST_DIR + "/" + file_path
        # 获取目标文件所在目录的path
        dst_dir_index = dst.rfind("/")
        dst_dir_path = dst[:dst_dir_index+1]
        # 判断一下目标目录是否存在，不存在则创建一下
        if not os.path.exists(dst_dir_path):
            os.makedirs(dst_dir_path)

        shutil.copy(src, dst)

    print("执行结束。\n")

