//
//  SortExercise.hpp
//  C2
//
//  Created by Harley Huang on 9/5/2021.
//

#ifndef SortExercise_hpp
#define SortExercise_hpp

#include <stdio.h>


class SortExercise {
    
public:
    //交换值
    void swapValue(int *a, int *b);
    
    /**
     *快速排序
     */
    void quickSort(int array[], int low, int high);
};


#endif /* SortExercise_hpp */
