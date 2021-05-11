//
//  SortExercise.cpp
//  C2
//
//  Created by Harley Huang on 9/5/2021.
//

#include "SortExercise.hpp"


void SortExercise::swapValue(int *a, int *b) {
    int c = *a;
    
    *a = *b;
    *b = c;
}

/**
 *快速排序
 */
void SortExercise::quickSort(int array[], int low, int high) {
    
    int keyValue = array[low];
    int i = low;
    int j = high;
    
    //如果low >= high说明排序结束了
    if (low >= high) {
        return;
    }
    
    while (low < high) {//该while循环结束一次表示比较了一轮 {100, 20, 60, -20, 200}
        
        while (low < high && array[high] >= keyValue) {
            --high;//往后查找
        }
        if (array[high] < keyValue) {
            swapValue(&(array[low]), &(array[high]));
            ++low;
        }
        
        
        while (array[low] <= keyValue && low < high) {
            
            ++low;
        }
        
        if (array[low] > keyValue) {
            //数值进行交换
            swapValue(&(array[low]), &(array[high]));
            --high;
        }
        
        
    }
    
    //用同样的方式对分出来的左边的部分进行同上的做法
    quickSort(array, i, low-1);
    //用同样的方式对分出来的右边的部分进行同上的做法
    quickSort(array, low+1, j);
    
    
}



