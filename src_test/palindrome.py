# -*- coding:utf-8 -*-

class Solution(object):
    def longestPalindrome(self, s):
        """
        滑动窗口来解决问题
        :type s: str
        :rtype: str
        """
        res = ''
        max_len = 0
        for i in range(len(s)):
            temp_len = 0
            while True:
                if i + temp_len + 1 > len(s):
                    break
                temp_str = s[i: i + temp_len + 1] # 这里要判断一下左右是否越界
                if temp_str == ''.join(reversed(temp_str)) and max_len <= temp_len:
                    max_len = temp_len
                    temp_len += 1
                    res = temp_str
                else:
                    temp_len += 1
        return res

if __name__ == '__main__':
    temp = Solution()
    temp.longestPalindrome("a")
