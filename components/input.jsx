import { StyleSheet, Text, TextInput, View } from 'react-native'
import React from 'react'
import { theme } from '../constants/theme'
import { hp, wp } from '../helpers/common'

const input = (props) => {
    return (
        <View style={[styles.container, props.containerStyle && props.containerStyle]}>
            {
                props.icon && props.icon}
            <TextInput
                style={{ flex: 1 }}
                placeholderTextColor={theme.colors.textLight}
                ref={props.inputRef && props.inputRef}
                {...props}
            />
        </View>
    )
}

export default input

const styles = StyleSheet.create({
    container: {
        flexDirection: 'row',
        height: hp(7.2),
        alignItems: 'center',
        justifyContent: 'center',
        borderWidth: 0.4,
        borderColor: theme.colors.text,
        borderRadius: theme.radius.xxl,
        borderCurve: 'continuous',
        paddingHorizontal: 18,
        gap: 12
    },
})