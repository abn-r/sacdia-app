import { View, Text, Button } from 'react-native'
import React from 'react'
import { useRouter } from 'expo-router'
import ScreenWrapper from '../components/screen_wrapper'

const index = () => {
    const router = useRouter();
    return (
        <ScreenWrapper>
            <Text>Hola</Text>
            <Button title='Ir a la aplicación' onPress={() => router.push('/welcome')} />
        </ScreenWrapper>
    )
}

export default index