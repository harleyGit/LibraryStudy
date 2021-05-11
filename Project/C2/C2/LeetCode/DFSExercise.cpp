//
//  DFSExercise.cpp
//  C2
//
//  Created by Harley Huang on 8/5/2021.
//

#include "DFSExercise.hpp"
#include <time.h>



int DFSExercise::minimumTimeRequired(std::vector<int>& jobs, int k) {
    int n = jobs.size();
    // 不排序 88ms
    sort(jobs.begin(), jobs.end()); // 40ms，从小到大
    // sort(jobs.rbegin(), jobs.rend()); // 680ms
    vector<int> time(k, 0);
    dfs(jobs, time, k, 0);
    return ans;
}

void DFSExercise::dfs(vector<int>& jobs, vector<int>& time, int k, int idx)
{
    if(idx == jobs.size())
    {
        int t = *max_element(time.begin(), time.end());
        if(t < ans)// 最大的时间总和 更小
            ans = t;
        return;
    }
    for(int i = 0; i < k; ++i)
    {
        if(time[i]+jobs[idx] > ans)
            //如果某人的时间超过答案，不可能是更优答案，剪枝
            continue;
        time[i] += jobs[idx];
        dfs(jobs, time, k, idx+1);
        time[i] -= jobs[idx];
        if(time[i] == 0)
            break;//搜完了，不加会超时
    }
}

