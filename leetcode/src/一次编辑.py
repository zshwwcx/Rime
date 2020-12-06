"""
https://leetcode-cn.com/problems/one-away-lcci/
字符串有三种编辑操作:插入一个字符、删除一个字符或者替换一个字符。 给定两个字符串，编写一个函数判定它们是否只需要一次(或者零次)编辑。
示例1:

输入:
first = "pale"
second = "ple"
输出: True

示例2:

输入:
first = "pales"
second = "pal"
输出: False

来源：力扣（LeetCode）
链接：https://leetcode-cn.com/problems/one-away-lcci
著作权归领扣网络所有。商业转载请联系官方授权，非商业转载请注明出处。
"""



class Solution(object):
    def oneEditAway(self, first, second):
        """
        :type first: str
        :type second: str
        :rtype: bool
        """
        if len(first) == 0 and len(second) == 1:
            return True

        elif len(first) == 1 and len(second) == 0:
            return True

        if len(first) == len(second):  # 尝试能否通过替换操作量进行编辑
            edit_time = 0
            for idx in range(len(first)):
                if first[idx] != second[idx]:
                    edit_time += 1
                    if edit_time > 1:
                        return False

            if edit_time <= 1:
                return True

            return False

        if abs(len(first) - len(second)) == 1:
            if len(first) - len(second) == -1:
                first, second = second, first

            edit_time = 0
            idx1 = 0
            idx2 = 0
            while idx1 < len(first) and idx2 < len(second):
                if edit_time > 1:
                    return False

                if first[idx1] != second[idx2]:
                    idx1 += 1
                    edit_time += 1

                idx1 += 1
                idx2 += 1
            if edit_time <= 1:
                return True
            return False

        return False


if __name__ == '__main__':
    temp = Solution()
    res = temp.oneEditAway('a', 'ab')
    print(res)