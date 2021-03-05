//
//  Chapter6.cpp
//  C2
//
//  Created by Harely Huang on 2020/10/28.
//

#include "Chapter6.hpp"
#include <stdio.h>
#include <stdlib.h>
#include "math.h"
#include "string.h"



Chapter6::BinaryTree *KthNodeCore(Chapter6::BinaryTree *pRoot, unsigned int& k);








Chapter6::BinaryTree *KthNodeCore(Chapter6::BinaryTree *pRoot, unsigned int& k) {
    
    Chapter6::BinaryTree *target = nullptr;
    
    if (pRoot->leftChild != nullptr) {
        target = KthNodeCore((pRoot->leftChild), k);
    }
    
    if(target == nullptr) {
        if (k == 1) {
            target = pRoot;
        }
        k--;
    }
    
    if (target == nullptr && pRoot->rightChild != nullptr) {
        target = KthNodeCore(pRoot->rightChild, k);
    }
    
    return target;
    
}




