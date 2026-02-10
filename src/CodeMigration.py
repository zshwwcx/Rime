import os
import shutil


def copy_files_with_structure(src_dir, dest_dir):
    # 遍历源目录
    for root, dirs, files in os.walk(src_dir):
        for file in files:
            # 检查文件扩展名
            if file.endswith('.h') or file.endswith('.cpp') or file.endswith('.lua'):
                if not file.endswith('.generated.h') and not file.endswith('.gen.cpp'):
                    # 构造源文件的完整路径
                    src_file = os.path.join(root, file)

                    # 计算相对路径并构造目标文件夹
                    relative_path = os.path.relpath(root, src_dir)
                    dest_folder = os.path.join(dest_dir, relative_path)

                    # 确保目标文件夹存在
                    os.makedirs(dest_folder, exist_ok=True)

                    # 构造目标文件的完整路径
                    dest_file = os.path.join(dest_folder, file)

                    # 复制文件
                    shutil.copy(src_file, dest_file)
                    print(f'复制: {src_file} 到 {dest_file}')


if __name__ == '__main__':
    # 示例用法
    source_directory = 'E:\P4_Project_UTF\Client\Content\Script\Framework'  # 替换为源文件夹路径
    destination_directory = 'F:\kuaishou-ue5-engine-code\Temp\Rime\cache\Framework'  # 替换为目标文件夹路径

    copy_files_with_structure(source_directory, destination_directory)

