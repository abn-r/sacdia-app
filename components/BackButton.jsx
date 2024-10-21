import { Pressable, StyleSheet } from 'react-native'
import React from 'react'
import Icon from '../assets/icons'
import { theme } from '../constants/theme'
import { router } from 'expo-router'
import ArrowLeftIcon from '../assets/icons/arrow_left'

const BackButton = (size=30) => {
  return (
    <Pressable onPress={()=> router.back()} style={styles.button}>
      <ArrowLeftIcon size={size} strokeWidth={3.5} color={theme.colors.text} />
    </Pressable>
  )
}

export default BackButton

const styles = StyleSheet.create({
    button:{
        alignSelf: 'flex-start',
        padding:10,
        borderRadius: theme.radius.sm,
        backgroundColor: 'rgba(0, 0, 0, 0.04)',
    }
})