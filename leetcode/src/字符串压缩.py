class Solution(object):
    def compressString(self, S):
        """
        :type S: str
        :rtype: str
        """
        rep_str = []
        same_char = ''
        last_char = same_char
        same_times = 0
        char_stack = []
        for i in S:
            if i == same_char:
                same_times += 1
            else:
                if same_times > 0:
                    rep_str.append(str(same_char + str(same_times)))
                same_times = 1
                same_char = i
        if same_times > 0:
            rep_str.append(str(same_char + str(same_times)))
        final_str = ''
        for i in rep_str:
            final_str = final_str + i

        if len(final_str) <= len(S):
            return final_str
        else:
            return S


if __name__ == '__main__':
    temp = Solution()
    res = temp.compressString("aabcccccaa")