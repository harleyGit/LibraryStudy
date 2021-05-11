//
//  DFSExercise.hpp
//  C2
//
//  Created by Harley Huang on 8/5/2021.
//
/**
 *广度优先概念：https://zhuanlan.zhihu.com/p/24986203
 *https://leetcode-cn.com/problems/find-minimum-time-to-finish-all-jobs/
 *title: 完成所有工作的最短时间
 给你一个整数数组 jobs ，其中 jobs[i] 是完成第 i 项工作要花费的时间。
 
 请你将这些工作分配给 k 位工人。所有工作都应该分配给工人，且每项工作只能分配给一位工人。工人的 工作时间 是完成分配给他们的所有工作花费时间的总和。请你设计一套最佳的工作分配方案，使工人的 最大工作时间 得以 最小化 。
 
 返回分配方案中尽可能 最小 的 最大工作时间 。
 *
 *
 * 示例 1：
 输入：jobs = [3,2,3], k = 3
 输出：3
 解释：给每位工人分配一项工作，最大工作时间是 3 。
 
 示例 2：
 输入：jobs = [1,2,4,7,8], k = 2
 输出：11
 解释：按下述方式分配工作：
 1 号工人：1、2、8（工作时间 = 1 + 2 + 8 = 11）
 2 号工人：4、7（工作时间 = 4 + 7 = 11）
 最大工作时间是 11 。
 
 提示：
 1 <= k <= jobs.length <= 12
 1 <= jobs[i] <= 10^7
 
 */

#ifndef DFSExercise_hpp
#define DFSExercise_hpp

#include <stdio.h>
#include <vector>

//std:: https://blog.csdn.net/Calvin_zhou/article/details/78440145
//std::是个名称空间标识符，C++标准库中的函数或者对象都是在命名空间std中定义的，所以我们要使用标准库中的函数或者对象都要用std来限定。
//向量（Vector）是一个封装了动态大小数组的顺序容器（Sequence Container）。跟任意其它类型容器一样，它能够存放各种类型的对象。可以简单的认为，向量是一个能够存放任意类型的动态数组。
using std::count;
using std::end;
using std::vector;



class DFSExercise {
    
    int ans = INT_MAX;
    
public:
    
    void dfs(vector<int>& jobs, vector<int>& time, int k, int idx);
    
    //传引用调用
    int minimumTimeRequired(vector<int>& jobs, int k);
    
    
    //快速排序
    void quickSort(int array[], int low, int high);
    
};

#endif /* DFSExercise_hpp */


