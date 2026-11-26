import { Box, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type CeremonialObjective = {
  name: string;
  description: string;
  progress?: string;
  completed: boolean;
  reward: number;
};

type Data = {
  objectives: CeremonialObjective[];
};

const theologistColor = '#d1c029';

export const TheologistCeremony = () => {
  const { data } = useBackend<Data>();
  const objectives = data.objectives || [];

  return (
    <Window title="Ceremonial Objectives" width={620} height={550}>
      <Window.Content scrollable style={{ position: 'relative' }}>
        <Box
          style={{
            position: 'absolute',
            inset: 0,
            backgroundColor: 'black',
            zIndex: 0,
          }}
        />
        <Box style={{ position: 'relative', zIndex: 1 }}>
          <Box color="label" mb={1}>
            You have been granted various ceremonies to complete. Performing the
            described actions will permanently increase Faithful Prayer's piety
            cap, as well as increasing it's channel speed and chance to grant
            Piety when outside of the Chapel!
          </Box>
          <Stack vertical>
            {objectives.map((objective) => (
              <Stack.Item key={objective.name}>
                <Section
                  style={{
                    background: objective.completed
                      ? 'rgba(209, 192, 41, 0.16)'
                      : 'rgba(209, 192, 41, 0.08)',
                    border: `1px solid ${theologistColor}`,
                    boxShadow: objective.completed
                      ? '0 0 16px rgba(209, 192, 41, 0.2)'
                      : 'none',
                  }}
                >
                  <Stack vertical>
                    <Stack.Item bold color={theologistColor}>
                      {objective.name}
                      {objective.completed ? ' - Completed' : ''}
                    </Stack.Item>
                    <Stack.Item>{objective.description}</Stack.Item>
                    {!!objective.progress && (
                      <Stack.Item color="label">
                        {objective.progress}
                      </Stack.Item>
                    )}
                    <Stack.Item color="label">
                      Reward: +{objective.reward} Piety Cap
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
            ))}
            {objectives.length === 0 && (
              <Stack.Item>
                <Box color="label">No ceremonial objectives are available.</Box>
              </Stack.Item>
            )}
          </Stack>
        </Box>
      </Window.Content>
    </Window>
  );
};
