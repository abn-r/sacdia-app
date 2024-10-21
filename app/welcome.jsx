import { StyleSheet, Text, View, Image, Pressable } from 'react-native'
import React from 'react'
import ScreenWrapper from '../components/screen_wrapper'
import { StatusBar } from 'expo-status-bar'
import { hp, wp } from '../helpers/common'
import { theme } from '../constants/theme'
import Button from '../components/button'
import { useRouter } from 'expo-router'

const Welcome = () => {
    const router = useRouter();

    return (
        <ScreenWrapper bg='white'>
            <StatusBar style='dark' />
            <View style={styles.container}>
                <Image style={styles.welcomeImage} resizeMode='contain' source={require('../assets/welcome.png')} />
                <View style={{ gap: 20 }}>
                    <Text style={styles.title}>Bienvenido</Text>
                    <Text style={styles.punchline}>SACDIA aplicación para la administración de clubes del Ministerio Juvenil ACV</Text>
                </View>
            </View>

            {/* Footer */}
            <View style={styles.footer}>
                <Button
                    title='Iniciar Sesión'
                    buttonStyle={{ marginHorizontal: wp(5) }}
                    //textStyle={{ fontSize: 30 }}
                    onPress={() => router.push('signup')}
                />
                <View style={styles.bottomTextContainer}>
                    <Text style={[
                        styles.loginText,
                        { paddingBottom: wp(3) }]}
                    >¿Ya tienes una cuenta?</Text>
                    <Pressable onPress={() => router.push('login')}>
                        <Text style={[styles.loginText, {
                            color: theme.colors.primaryDark,
                            fontWeight: theme.fonts.semibold,
                            paddingBottom: wp(3)
                        }]}>Inicia Sesión</Text>
                    </Pressable>
                </View>
            </View>
        </ScreenWrapper>
    )
}

export default Welcome

const styles = StyleSheet.create({
    container: {
        flex: 1,
        alignItems: 'center',
        justifyContent: 'space-around',
        backgroundColor: 'white',
        paddingHorizontal: wp(4),
    },
    welcomeImage: {
        height: hp(30),
        width: wp(100),
        alignSelf: 'center',
    },
    title: {
        fontSize: hp(8),
        color: theme.colors.text,
        fontWeight: theme.fonts.extrabold,
        textAlign: 'center',
    },
    punchline: {
        textAlign: 'center',
        paddingHorizontal: hp(10),
        fontSize: hp(4),
        color: theme.colors.text
    },
    footer: {
        gap: 30,
        width: '100%',
    },
    bottomTextContainer: {
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        gap: 5,
    },
    loginText: {
        textAlign: 'center',
        color: theme.colors.text,
        fontSize: hp(3),
    },
})